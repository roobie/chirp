# `chirp --help serve`: the offline help in a browser. Pages are rendered on the
# server so they work without JS; the few lines of script only make search
# update as you type. Everything comes from the image, nothing from the network.
(import md4c)
(import spork/http)

(defn- escape [s]
  (->> (string s) (string/replace-all "&" "&amp;") (string/replace-all "\"" "&quot;")
       (string/replace-all "<" "&lt;") (string/replace-all ">" "&gt;")))

# Ids hold bytes such as `?`, `*` and `>` (Janet core names); `/` stays literal
# so `spork-https/get` reads as a path.
(defn- url-encode [s]
  (peg/replace-all ~(if-not (+ (range "az" "AZ" "09") (set "-._~/")) 1)
                   (fn [c] (string/format "%%%02X" (c 0))) s))

(defn- url-decode [s]
  # A string, not the buffer peg/replace-all returns, so it can key a table.
  (string (peg/replace-all ~(* "%" (<- (2 (+ (range "09" "af" "AF")))))
                           (fn [_ hex] (string/from-bytes (scan-number hex 16))) s)))

(defn- link [id] (string "/read/" (url-encode id)))

(def- script
  `(function () {
  var form = document.getElementById('q-form'), box = document.getElementById('q'),
      out = document.getElementById('results'), timer, last = 0;
  if (!form || !box || !out || !window.fetch) return;
  box.addEventListener('input', function () {
    clearTimeout(timer);
    timer = setTimeout(function () {
      var q = box.value.trim(), mine = ++last;
      history.replaceState(null, '', q ? '/search?q=' + encodeURIComponent(q) : location.pathname);
      if (!q) { out.innerHTML = ''; return; }
      fetch('/search?fragment=1&q=' + encodeURIComponent(q))
        .then(function (r) { return r.text(); })
        .then(function (html) { if (mine === last) out.innerHTML = html; })
        .catch(function () {});
    }, 200);
  });
})();`)

(defn- page [config status title body]
  {:status status
   :headers {"Content-Type" "text/html; charset=utf-8"}
   :body (string
           "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
           "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
           "<title>" (escape title) " · chirp</title>\n"
           "<link rel=\"stylesheet\" href=\"/style.css\">\n</head>\n<body>\n"
           "<header><nav><a href=\"/\">chirp help</a></nav></header>\n"
           "<main>\n" body "</main>\n"
           "<footer>chirp " (escape (config :version))
           ". chirp is an unofficial build of Janet.</footer>\n"
           "<script>" script "</script>\n</body>\n</html>\n")})

(defn- search-box [q]
  (string "<form id=\"q-form\" class=\"search\" action=\"/search\" method=\"get\" role=\"search\">"
          "<input id=\"q\" type=\"search\" name=\"q\" value=\"" (escape q)
          "\" placeholder=\"Search the help\" aria-label=\"Search the help\" autofocus> "
          "<button type=\"submit\">Search</button></form>\n"))

# The same markup is the whole results area of the page and the fragment the
# script swaps in.
(defn- results-html [search q]
  (if (empty? q)
    [200 ""]
    (let [[ok rows] (search q 50)]
      (cond
        (not ok) [400 (string "<p class=\"error\">Invalid query: " (escape rows) "</p>\n")]
        (empty? rows) [200 "<p>No matches.</p>\n"]
        [200 (string "<ul class=\"results\">\n"
                     ;(seq [{:id id :title title :s s} :in rows]
                        (string "<li><a href=\"" (link id) "\"><code>" (escape id) "</code> "
                                (escape title) "</a><br><small>" (escape s) "</small></li>\n"))
                     "</ul>\n")]))))

(defn- text-response [status type body]
  {:status status :headers {"Content-Type" type} :body body})

(defn- not-found [config what]
  (page config 404 "Not found"
        (string "<h1>Not found</h1>\n<p>" (escape what) "</p>\n<p><a href=\"/\">Back to the topics</a></p>\n")))

(defn serve
  "Serve the help entries over HTTP and block. `search` is (fn [q limit]) ->
  [ok rows|message] over an index built once; config holds :host, :port, :style
  (the stylesheet text) and :version."
  [entries search config]
  (def by-id (tabseq [e :in entries] (e :id) e))
  (def sections-of @{})
  (each e entries
    (when (= :section (e :kind))
      (def stem (string/slice (e :id) 0 (string/find "/" (e :id))))
      (put sections-of stem (array/push (get sections-of stem @[]) e))))

  (defn home []
    (page config 200 "Help"
          (string "<h1>chirp help</h1>\n" (search-box "")
                  "<div id=\"results\"></div>\n<h2>Topics</h2>\n<ul>\n"
                  ;(seq [e :in entries :when (= :topic (e :kind))]
                     (string "<li><a href=\"" (link (e :id)) "\"><code>" (escape (e :id))
                             "</code></a> " (escape (e :title)) "</li>\n"))
                  "</ul>\n")))

  (defn search-page [query]
    (def q (string/trim (let [v (get query "q")] (if (string? v) v ""))))
    (def [status html] (results-html search q))
    (if (truthy? (get query "fragment"))
      (text-response status "text/html; charset=utf-8" html)
      (page config status (if (empty? q) "Search" (string "Search: " q))
            (string "<h1>Search</h1>\n" (search-box q) "<div id=\"results\">\n" html "</div>\n"))))

  (defn entry-page [id]
    (if-let [e (by-id id)]
      (page config 200 (if (= :doc (e :kind)) id (e :title))
            (case (e :kind)
              :doc (string "<h1><code>" (escape id) "</code></h1>\n<pre>" (escape (e :text)) "</pre>\n"
                           (when (e :source)
                             (string "<h2>Source</h2>\n<p><code>" (escape (e :source-at)) "</code></p>\n"
                                     "<pre><code>" (escape (e :source)) "</code></pre>\n")))
              (string
                (when (= :section (e :kind))
                  (def stem (string/slice id 0 (string/find "/" id)))
                  (string "<p><a href=\"" (link stem) "\">&larr; "
                          (escape (get-in by-id [stem :title] stem)) "</a></p>\n"))
                (md4c/to-html (e :text) {:github true})
                (when-let [secs (and (= :topic (e :kind)) (sections-of id))]
                  (string "<h2>Sections</h2>\n<ul>\n"
                          ;(seq [s :in secs]
                             (string "<li><a href=\"" (link (s :id)) "\">" (escape (s :title)) "</a></li>\n"))
                          "</ul>\n")))))
      (not-found config (string "No help entry " id "."))))

  (defn route [req]
    (def path (req :route))
    (cond
      (not (or (= "GET" (req :method)) (= "HEAD" (req :method))))
      (text-response 405 "text/plain; charset=utf-8" "method not allowed\n")
      (= "/" path) (home)
      (= "/search" path) (search-page (req :query))
      (= "/style.css" path) (text-response 200 "text/css; charset=utf-8" (config :style))
      (string/has-prefix? "/read/" path) (entry-page (url-decode (string/slice path 6)))
      (not-found config (string "No page " path "."))))

  # spork/http drops the connection when a handler throws, so a failure is
  # caught here to answer 500 and keep serving.
  (defn handler [req]
    (def [ok res] (protect (route req)))
    (if ok
      res
      (do (eprint "chirp --help serve: " res)
          (page config 500 "Error" "<h1>Server error</h1>\n<p>The request failed.</p>\n"))))

  (def host (config :host))
  (def port (config :port))
  # net/server with no-reuse, not http/server: that one sets SO_REUSEPORT, so
  # a second server on a taken port would bind silently instead of failing.
  (def [ok err] (protect (net/server host (string port)
                                     (fn [conn] (http/server-handler conn handler))
                                     :stream true)))
  (unless ok
    (eprint "chirp --help: cannot listen on " host ":" port ": " err)
    (os/exit 1))
  (print "serving chirp help at http://" host ":" port "/ (Ctrl-C stops)")
  (file/flush stdout)
  (forever (ev/sleep 3600)))
