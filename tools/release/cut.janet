# Cut a release, or move main to the next -dev, by editing files only: the
# commit, push and tag stay human steps, and every check runs before any write
# so a refusal leaves the tree untouched. Paths come from cut.jdn.
#   chirp cut.janet [X.Y.Z] [--root DIR]         drop -dev, date the changelog
#   chirp cut.janet --next [X.Y.Z] [--root DIR]  after the release: X.Y.Z-dev

(def- here
  (let [f (dyn :current-file)]
    (if-let [s (last (string/find-all "/" f))] (string/slice f 0 s) ".")))

(defn- die [& msg] (eprint "cut: " ;msg) (os/exit 1))

(defn- sh [dir & args]
  (def p (os/spawn ["git" "-C" dir ;args] :p{:out :pipe :err :pipe}))
  (def out (ev/read (p :out) :all))
  (def err (ev/read (p :err) :all))
  (def code (os/proc-wait p))
  (when (not= code 0) (die "git " (string/join args " ") " failed: " (string/trim (string err))))
  (string/trim (or out "")))

(def- semver ~(sequence :d+ "." :d+ "." :d+ -1))
(defn- plain? [v] (and (string? v) (peg/match semver v)))

(defn- lines-of [text] (string/split "\n" text))

# Start of the version string inside `:version "..."`, and the string itself.
(defn- version-span [text]
  (def hits (string/find-all ":version \"" text))
  (unless (= 1 (length hits)) (die "expected exactly one :version in the version file"))
  (def start (+ (first hits) 10))
  (def end (string/find "\"" text start))
  [start end])

(defn- section-at [lines heading]
  (find-index |(= $ heading) lines))

(defn- section-end [lines i]
  (var j (+ i 1))
  (while (and (< j (length lines)) (not (string/has-prefix? "## " (lines j)))) (++ j))
  j)

(defn- example-hits [text]
  (def pat ~(sequence "# chirp " (capture (sequence :d+ "." :d+ "." :d+)) " "))
  (seq [i :in (string/find-all "# chirp " text)
        :let [m (peg/match pat text i)]
        :when m]
    [(+ i 8) (+ i 8 (length (first m)))]))

(defn main [_ & args]
  (var next? false)
  (var root nil)
  (var wanted nil)
  (var i 0)
  (while (< i (length args))
    (def a (args i))
    (cond
      (= a "--next") (set next? true)
      (= a "--root") (set root (args (++ i)))
      wanted (die "unexpected argument " a)
      (set wanted a))
    (++ i))
  (def dir (or root (sh "." "rev-parse" "--show-toplevel")))
  (def cfg (parse (slurp (string here "/cut.jdn"))))
  (def vpath (string dir "/" (cfg :version-file)))
  (def cpath (string dir "/" (cfg :changelog)))

  (unless (= "main" (sh dir "rev-parse" "--abbrev-ref" "HEAD")) (die "not on branch main"))
  (unless (empty? (sh dir "status" "--porcelain")) (die "working tree is not clean"))

  (def vtext (slurp vpath))
  (def [vs ve] (version-span vtext))
  (def current (string/slice vtext vs ve))
  (def ctext (slurp cpath))
  (def clines (lines-of ctext))

  (when wanted (unless (plain? wanted) (die "version must be N.N.N, got " wanted)))

  (var edits @[]) # [path new-text], written only after every check passed
  (var steps nil)

  (if next?
    (do
      (unless (plain? current) (die "current version " current " is not a plain N.N.N release"))
      (unless (section-at clines (string "## " current))
        (die "CHANGELOG has no section for " current))
      (when (section-at clines "## Unreleased") (die "CHANGELOG already has ## Unreleased"))
      (def target
        (or wanted
            (let [[maj min] (map scan-number (string/split "." current))]
              (string maj "." (+ min 1) ".0"))))
      (def first-h (find-index |(string/has-prefix? "## " $) clines))
      (unless first-h (die "CHANGELOG has no version section"))
      (array/push edits
        [vpath (string (string/slice vtext 0 vs) target "-dev" (string/slice vtext ve))]
        [cpath (string/join [;(array/slice clines 0 first-h) "## Unreleased" ""
                             ;(array/slice clines first-h)] "\n")])
      (set steps [(string "Commit, e.g. \"main moves to " target "-dev after the " current " release\".")]))
    (do
      (unless (string/has-suffix? "-dev" current) (die "current version " current " does not end in -dev"))
      (def target (or wanted (string/slice current 0 (- (length current) 4))))
      (def u (section-at clines "## Unreleased"))
      (unless u (die "CHANGELOG has no ## Unreleased section"))
      (def body (array/slice clines (+ u 1) (section-end clines u)))
      (when (all |(empty? (string/trim $)) body) (die "## Unreleased is empty"))
      (when (section-at clines (string "## " target)) (die "CHANGELOG already has a section for " target))
      (def d (os/date nil true))
      (def date (string/format "%04d-%02d-%02d" (d :year) (+ 1 (d :month)) (+ 1 (d :month-day))))
      (def rest-lines (array/slice clines (+ u 1)))
      (def sep (if (empty? (string/trim (first rest-lines))) [] [""]))
      (array/push edits
        [vpath (string (string/slice vtext 0 vs) target (string/slice vtext ve))]
        [cpath (string/join [;(array/slice clines 0 u) (string "## " target) ""
                             (string "Released " date ".") ;sep ;rest-lines] "\n")])
      (each f (cfg :examples)
        (def p (string dir "/" f))
        (def t (slurp p))
        (def hits (example-hits t))
        (unless (= 1 (length hits)) (die f " needs exactly one `# chirp N.N.N ` example, found " (length hits)))
        (def [s e] (first hits))
        (array/push edits [p (string (string/slice t 0 s) target (string/slice t e))]))
      (set steps [(string "Commit, e.g. \"release: " target "\", and push; wait for CI to go green.")
                  (string "Tag that commit: git tag -a v" target " <sha> -m \"chirp " target "\"")
                  "Push the tag, and once the release is published run: chirp tools/release/cut.janet --next"])))

  (each [p t] edits (spit p t))
  (print "edited: " (string/join (map first edits) ", "))
  (print "next:")
  (each s steps (print "  - " s)))
