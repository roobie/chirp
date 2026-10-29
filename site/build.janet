# Builds chirp's static site from the repo's own Markdown, so the site cannot
# drift from the binary's docs or from the dev-proc skill.
# Usage: chirp site/build.janet [outdir]   (default out/site; run from the repo root)
# Needs a chirp that bundles md4c. The build fails on a relative link it cannot
# resolve and on a commit link to a commit this checkout does not have.
(import md4c)
(import spork/sh)

(def- repo-url "https://github.com/roobie/chirp")
(def- out-dir (get (dyn :args) 1 "out/site"))

(defn- die [& msg] (eprint "site: " ;msg) (os/exit 1))

(defn- git [& args] (string/trim (sh/exec-slurp "git" ;args)))

# Links to repo files point at the exact commit the site was built from.
(def- sha (git "rev-parse" "HEAD"))

(defn- strip-front-matter [text]
  (if-let [m (peg/match ~(* "---\n" (thru "\n---\n") (position)) text)]
    (string/slice text (m 0))
    text))

(defn- first-heading [text]
  (if-let [m (peg/match ~(* (any (* (not "# ") (thru "\n"))) "# " (<- (to "\n"))) text)]
    (m 0)
    (die "no '# ' heading in a source")))

# Pages: url is relative to the site root; each source is [path text].
(def- help-files
  (sorted (filter |(string/has-suffix? ".md" $) (os/dir "src/chirp/help"))))

(defn- src [path &opt front?]
  (def text (slurp path))
  [path (if front? (strip-front-matter text) text)])

(def- pages
  @[{:url "index.html" :nav "chirp" :sources [(src "README.md")]}
    {:url "changelog.html" :nav "Changelog" :sources [(src "CHANGELOG.md")]}
    ;(seq [f :in help-files]
       {:url (string "help/" (string/slice f 0 -4) ".html")
        :sources [(src (string "src/chirp/help/" f))]})
    {:url "dev-proc/index.html" :nav "dev-proc"
     :sources [(src "site/dev-proc.md") (src ".agents/skills/dev-proc/SKILL.md" true)]}
    {:url "dev-proc/examples.html" :sources [(src "site/dev-proc-examples.md")]}])

# The help index is generated, so it lists exactly the topics the binary has.
(array/insert pages 2
  {:url "help/index.html" :nav "Help"
   :sources [["site/help-index.md"
              (string "# Help topics\n\nThe same text is inside the binary: `chirp -h` lists it, "
                      "`chirp --help query '<words>'` searches it with every bundled module's docstrings.\n\n"
                      ;(seq [p :in pages :when (string/has-prefix? "help/" (p :url))]
                         (def [path text] ((p :sources) 0))
                         (string "- [" (first-heading text) "](../" path ")\n")))]]})

# A source path maps to the page that renders it.
(def- page-of @{})
(each p pages (each [path] (p :sources) (put page-of path (p :url))))

(defn- normalize [path]
  (def out @[])
  (each part (string/split "/" path)
    (case part
      "" nil
      "." nil
      ".." (if (empty? out) (die "link leaves the repo: " path) (array/pop out))
      (array/push out part)))
  (string/join out "/"))

(defn- dirname [path]
  (if-let [i (last (string/find-all "/" path))] (string/slice path 0 (+ i 1)) ""))

(defn- rel-root [url] (string/repeat "../" (length (string/find-all "/" url))))

(defn- rewrite-href [href from-path page-url]
  (cond
    (string/has-prefix? "#" href) href
    (peg/match ~(* (some (+ (range "az" "AZ") (set "+.-"))) ":") href)
    (do
      (when-let [m (peg/match ~(* ,(string repo-url "/commit/") (<- (some (range "09" "af"))) -1) href)]
        (unless (= 0 (os/execute ["git" "cat-file" "-e" (string (m 0) "^{commit}")] :p))
          (die from-path ": no commit " (m 0) " in this checkout")))
      href)
    (let [[path frag] (let [i (string/find "#" href)]
                        (if i [(string/slice href 0 i) (string/slice href i)] [href ""]))
          target (normalize (string (dirname from-path) path))]
      (cond
        (page-of target) (string (rel-root page-url) (page-of target) frag)
        (os/stat target)
        (string repo-url (if (= :directory (os/stat target :mode)) "/tree/" "/blob/") sha "/" target frag)
        (die from-path ": link to " href " resolves to " target ", which does not exist")))))

(defn- unescape [s]
  (->> s (string/replace-all "&amp;" "&") (string/replace-all "&quot;" "\"")))

(defn- escape [s]
  (->> s (string/replace-all "&" "&amp;") (string/replace-all "\"" "&quot;")
       (string/replace-all "<" "&lt;") (string/replace-all ">" "&gt;")))

# Links are resolved before the replace: checking a commit runs git, which
# cannot yield from inside peg/replace-all's callback.
(def- href-peg ~(* "href=\"" (<- (to "\"")) "\""))

(defn- fix-links [html from-path page-url]
  (def resolved @{})
  (each href (or (peg/match ~(any (+ ,href-peg 1)) html) [])
    (put resolved href (escape (rewrite-href (unescape href) from-path page-url))))
  (peg/replace-all href-peg (fn [_ href] (string "href=\"" (resolved href) "\"")) html))

# GitHub-style ids, so #anchors written for the repo also work on the site.
(defn- slug [inner]
  (def text (peg/replace-all ~(* "<" (thru ">")) "" inner))
  (def text (peg/replace-all ~(* "&" (thru ";")) "" text))
  (->> (string/ascii-lower text)
       (peg/replace-all ~(if-not (+ (range "az" "09") (set " -_") (range "\x80\xFF")) 1) "")
       (string/replace-all " " "-")))

(defn- add-ids [html]
  (def seen @{})
  (peg/replace-all ~(* "<h" (<- (range "16")) ">" (<- (to "</h")) "</h" (range "16") ">")
                   (fn [_ level inner]
                     (def base (slug inner))
                     (def n (get seen base 0))
                     (put seen base (+ n 1))
                     (def id (if (= n 0) base (string base "-" n)))
                     (string "<h" level " id=\"" id "\"><a class=\"anchor\" href=\"#" id "\">#</a>"
                             inner "</h" level ">"))
                   html))

(defn- nav [page-url]
  (string/join
    (seq [p :in pages :when (p :nav)]
      # A section's index also marks the other pages in its directory.
      (def dir (dirname (p :url)))
      (def here (or (= (p :url) page-url)
                    (and (not= dir "") (string/has-prefix? dir page-url))))
      (string "<a href=\"" (rel-root page-url) (p :url) "\"" (if here " aria-current=\"page\"" "") ">"
              (escape (p :nav)) "</a>"))
    "\n"))

# The version word of `chirp --version`'s first line, "chirp 0.4.0 (…) on Janet …".
(def- chirp-version
  (get (string/split " " (sh/exec-slurp (dyn :executable) "--version")) 1 "unknown"))

(defn- render [page]
  (def url (page :url))
  (def body
    (string/join
      (seq [[path text] :in (page :sources)]
        (fix-links (md4c/to-html text {:github true}) path url))
      "\n<hr>\n"))
  (def title (first-heading ((first (page :sources)) 1)))
  (string
    "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
    "<title>" (escape (if (= title "chirp") "chirp" (string title " · chirp"))) "</title>\n"
    "<link rel=\"stylesheet\" href=\"" (rel-root url) "style.css\">\n</head>\n<body>\n"
    "<header><nav>\n" (nav url) "\n<a href=\"" repo-url "\">GitHub</a>\n</nav></header>\n"
    "<main>\n" (add-ids body) "</main>\n"
    "<footer>Built from <a href=\"" repo-url "/commit/" sha "\"><code>" (string/slice sha 0 7)
    "</code></a> with chirp " (escape chirp-version)
    ". chirp is an unofficial build of Janet.</footer>\n</body>\n</html>\n"))

(each p pages
  (def dest (string out-dir "/" (p :url)))
  (sh/create-dirs-to dest)
  (spit dest (render p)))
(spit (string out-dir "/style.css") (slurp "site/style.css"))
(spit (string out-dir "/.nojekyll") "")
(print "site: " (length pages) " pages in " out-dir)
