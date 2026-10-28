# Checks a built site, or the live one, by its structure rather than its text.
# Usage: chirp site/check.janet <dir|https://…/> [--commit <sha>] [--chirp-version <v>] [--wait <seconds>]
# Pages are found by following links from index.html, the same way in a
# directory and on the web. Every failure names the page and the rule; the
# exit code is 1 if any rule fails. --wait polls a live site until its footer
# names --commit, since Pages can serve the previous deploy for a while.
# Needs a chirp that bundles lexbor.
(import lexbor)
(import spork-https :as https)

(def- usage "usage: chirp site/check.janet <dir|https://…/> [--commit <sha>] [--chirp-version <v>] [--wait <seconds>]")

(defn- parse-args [args]
  (def opts @{})
  (var i 0)
  (while (< i (length args))
    (def a (args i))
    (case a
      "--commit" (do (put opts :commit (get args (+ i 1))) (+= i 2))
      "--chirp-version" (do (put opts :chirp-version (get args (+ i 1))) (+= i 2))
      "--wait" (do (put opts :wait (scan-number (get args (+ i 1) ""))) (+= i 2))
      (if (or (opts :site) (string/has-prefix? "-" a))
        (do (eprint usage) (os/exit 2))
        (do (put opts :site a) (++ i)))))
  (each k [:site :commit :chirp-version]
    (when (and (has-key? opts k) (nil? (opts k))) (eprint usage) (os/exit 2)))
  (when (and (has-key? opts :wait) (nil? (opts :wait))) (eprint usage) (os/exit 2))
  (unless (opts :site) (eprint usage) (os/exit 2))
  opts)

(def- opts (parse-args (slice (dyn :args) 1)))
(def- live? (truthy? (peg/match ~(* "http" (? "s") "://") (opts :site))))
(def- base (if (string/has-suffix? "/" (opts :site)) (opts :site) (string (opts :site) "/")))

# The body at a site path such as "help/index.html", or nil when there is none.
(defn- fetch [path]
  (if live?
    (let [r (https/request "GET" (string base path))]
      (case (r :status)
        200 (string (r :body))
        404 nil
        (errorf "GET %s%s: status %d" base path (r :status))))
    (let [f (string base path)]
      (when (= :file (os/stat f :mode)) (slurp f)))))

(def- failures @[])
(defn- fail [page rule & detail]
  (array/push failures (string page ": " rule (if (empty? detail) "" (string ": " ;detail)))))

# Site paths

(defn- dirname [path]
  (if-let [i (last (string/find-all "/" path))] (string/slice path 0 (+ i 1)) ""))

(defn- normalize [path]
  (def out @[])
  (var escaped false)
  (each part (string/split "/" path)
    (case part
      "" nil
      "." nil
      ".." (if (empty? out) (set escaped true) (array/pop out))
      (array/push out part)))
  (unless escaped
    (def p (string/join out "/"))
    (if (or (= p "") (string/has-suffix? "/" path)) (string p (if (= p "") "" "/") "index.html") p)))

# A link that stays on the site, as [path fragment], or nil for any other link.
# A fragment-only link points at its own page.
(defn- internal [href page]
  (unless (or (peg/match ~(* (some (+ (range "az" "AZ") (set "+.-"))) ":") href)
              (string/has-prefix? "//" href))
    (def [before frag] (if-let [i (string/find "#" href)]
                         [(string/slice href 0 i) (string/slice href (+ i 1))]
                         [href nil]))
    (def path (first (string/split "?" before)))
    [(if (= path "") page (normalize (string (dirname page) path))) frag]))

# Crawl

(def- docs @{})   # page path -> parsed document, for every HTML page reached
(def- other @{})  # path -> true, for anything else that was found, such as style.css
(def- missing @{}) # path -> true

(defn- load [path]
  (cond
    (or (docs path) (other path) (missing path)) nil
    (string/has-suffix? ".html" path)
    (if-let [body (fetch path)] (put docs path (lexbor/parse body)) (put missing path true))
    (if (fetch path) (put other path true) (put missing path true))))

(defn- crawl []
  (def queue @["index.html"])
  (while (not (empty? queue))
    (def page (array/pop queue))
    (unless (docs page)
      (load page)
      (when-let [d (docs page)]
        (each el (lexbor/select d "a[href], link[href]")
          (when-let [[path] (internal (lexbor/attr el "href") page)
                     _ path]
            (if (string/has-suffix? ".html" path)
              (unless (or (docs path) (missing path)) (array/push queue path))
              (load path))))))))

# The commit in a page's footer, from its link to the commit.
(defn- footer-commit [d]
  (when-let [a (lexbor/select-first d "footer a[href*='/commit/']")]
    (last (string/split "/" (lexbor/attr a "href")))))

(when (and live? (opts :wait))
  (unless (opts :commit) (eprint "site check: --wait needs --commit") (os/exit 2))
  (def deadline (+ (os/clock) (opts :wait)))
  (forever
    (def body (protect (fetch "index.html")))
    (def got (when (and (body 0) (body 1)) (footer-commit (lexbor/parse (body 1)))))
    (when (= got (opts :commit)) (break))
    (when (> (os/clock) deadline)
      (eprintf "site check: %s still serves commit %s after %ds, not %s" base (or got "none") (opts :wait) (opts :commit))
      (os/exit 1))
    (ev/sleep 10)))

(crawl)
(when (missing "index.html") (eprint "site check: no index.html at " base) (os/exit 1))

# Rules, per page

(defn- check-page [page d]
  (def title (lexbor/select-first d "head > title"))
  (when (or (nil? title) (empty? (string/trim (lexbor/text title))))
    (fail page "title" "missing or empty"))
  (unless (lexbor/attr d "lang") (fail page "lang" "<html> has no lang"))

  (def nav (lexbor/select-first d "header > nav"))
  (if (nil? nav)
    (fail page "nav" "no <header><nav>")
    (do
      (unless (lexbor/select-first nav "a[href='https://github.com/roobie/chirp']")
        (fail page "nav" "no GitHub link"))
      (def current (lexbor/select nav "a[aria-current=page]"))
      (unless (= 1 (length current))
        (fail page "nav" (string (length current) " links marked current, not 1")))))

  (def ids (map |(lexbor/attr $ "id") (lexbor/select d "[id]")))
  (def seen @{})
  (each id ids
    (when (seen id) (fail page "ids" "\"" id "\" is used more than once"))
    (put seen id true))

  (each el (lexbor/select d "a[href], link[href]")
    (def href (lexbor/attr el "href"))
    (when-let [[path frag] (internal href page)]
      (cond
        (nil? path) (fail page "links" href " leaves the site")
        (missing path) (fail page "links" href " -> " path ", which does not exist")
        (and frag (not= frag ""))
        (if-let [target (docs path)]
          (unless (lexbor/select-first target (string "[id=\"" (string/replace-all "\"" "\\\"" frag) "\"]"))
            (fail page "links" href " -> no id \"" frag "\" on " path))
          (fail page "links" href " has a fragment but " path " is not a page")))))

  (unless (lexbor/select-first d "head > link[rel=stylesheet][href]")
    (fail page "stylesheet" "no <link rel=stylesheet>"))

  (def footer (lexbor/select-first d "body > footer"))
  (if (nil? footer)
    (fail page "footer" "no <footer>")
    (let [commit (footer-commit d)
          text (lexbor/text footer)
          version (when-let [m (peg/match ~(* (thru " with chirp ") (<- (to ". "))) text)] (m 0))]
      (cond
        (nil? commit) (fail page "footer" "no commit link")
        (and (opts :commit) (not= commit (opts :commit)))
        (fail page "footer" "commit " commit ", expected " (opts :commit)))
      (cond
        (nil? version) (fail page "footer" "no chirp version")
        (and (opts :chirp-version) (not= version (opts :chirp-version)))
        (fail page "footer" "chirp " version ", expected " (opts :chirp-version))))))

(eachp [page d] docs (check-page page d))

# In a directory, an HTML file that no link reaches is a page readers cannot find.
(unless live?
  (defn- walk [dir rel]
    (each e (os/dir dir)
      (def f (string dir "/" e))
      (def r (string rel e))
      (case (os/stat f :mode)
        :directory (walk f (string r "/"))
        :file (when (and (string/has-suffix? ".html" r) (not (docs r)))
                (fail r "orphan" "no page links to it")))))
  (walk (string/slice base 0 -2) ""))

(sort failures)
(each f failures (eprint "site check: " f))
(if (empty? failures)
  (print "site check: " (length docs) " pages ok at " base)
  (do (eprint "site check: " (length failures) " failures") (os/exit 1)))
