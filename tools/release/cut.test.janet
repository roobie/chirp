# Run from the repo root: chirp tools/release/cut.test.janet
# Each case gets a throwaway git repo so the script is exercised end to end.

(def script (string (os/cwd) "/tools/release/cut.janet"))
(def chirp (dyn :executable))
(def base (or (os/getenv "TMPDIR") "/tmp"))

(def jdn-fixture "{# note\n :version \"%s\"\n :other 1}\n")
(def readme-fixture "intro\nchirp --version          # chirp 0.6.0 (unofficial)\nmore\n")
(def changelog-fixture
  (string "# Changelog\n\nintro\n\n## Unreleased\n\n### Added\n\n- a thing\n\n"
          "## 0.6.0\n\nReleased 2026-01-02.\n\n### Added\n\n- old\n"))

(var failures 0)
(defn check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(defn run [& args]
  (def p (os/spawn args :p {:out :pipe :err :pipe}))
  (def out (ev/read (p :out) :all))
  (def err (ev/read (p :err) :all))
  [(os/proc-wait p) (string out err)])

(defn git [dir & args]
  (def [code out] (run "git" "-C" dir "-c" "user.name=t" "-c" "user.email=t@example.org" ;args))
  (unless (zero? code) (error (string "git failed: " out))))

(var counter 0)
(defn fixture
  "Builds a repo; opts override :version :branch :changelog :dirty."
  [&named version branch changelog dirty]
  (def dir (string base "/chirp-cut-" (os/getpid) "-" (++ counter)))
  (os/mkdir dir)
  (os/mkdir (string dir "/src"))
  (os/mkdir (string dir "/src/chirp"))
  (spit (string dir "/src/chirp/chirp.jdn") (string/format jdn-fixture (or version "0.7.0-dev")))
  (spit (string dir "/CHANGELOG.md") (or changelog changelog-fixture))
  (spit (string dir "/README.md") readme-fixture)
  (git dir "init" "-q" "-b" (or branch "main"))
  (git dir "add" ".")
  (git dir "commit" "-q" "-m" "init")
  (when dirty (spit (string dir "/stray") "x"))
  dir)

(defn snapshot [dir]
  (map |(string (slurp (string dir "/" $))) ["src/chirp/chirp.jdn" "CHANGELOG.md" "README.md"]))

(defn cut [dir & args] (run chirp script ;args "--root" dir))

(defn today []
  (def d (os/date nil true))
  (string/format "%04d-%02d-%02d" (d :year) (+ 1 (d :month)) (+ 1 (d :month-day))))

(defn cleanup [dir] (run "rm" "-rf" dir))

(defn refused [name why opts &opt args]
  (def dir (fixture ;(kvs opts)))
  (def before (snapshot dir))
  (def [code out] (cut dir ;(or args [])))
  (check (string name ": exit") (not= code 0) true)
  (check (string name ": reason") (not (nil? (string/find why out))) true)
  (check (string name ": files unchanged") (snapshot dir) before)
  (cleanup dir))

(defn release-case [name args want-version]
  (def dir (fixture))
  (def [code out] (cut dir ;args))
  (check (string name ": exit") [code out] [0 out])
  (check (string name ": version file") ((snapshot dir) 0)
         (string/format jdn-fixture want-version))
  (check (string name ": changelog") ((snapshot dir) 1)
         (string "# Changelog\n\nintro\n\n## " want-version "\n\nReleased " (today) ".\n\n### Added\n\n- a thing\n\n"
                 "## 0.6.0\n\nReleased 2026-01-02.\n\n### Added\n\n- old\n"))
  (check (string name ": readme") ((snapshot dir) 2)
         (string/replace "0.6.0" want-version readme-fixture))
  (check (string name ": prints next steps") (not (nil? (string/find "git tag -a v" out))) true)
  (cleanup dir))

(release-case "release" [] "0.7.0")
(release-case "explicit version" ["0.8.1"] "0.8.1")

(def released-changelog
  (string "# Changelog\n\nintro\n\n## 0.7.0\n\nReleased 2026-02-03.\n\n### Added\n\n- a thing\n\n"
          "## 0.6.0\n\nReleased 2026-01-02.\n\n### Added\n\n- old\n"))

(let [dir (fixture :version "0.7.0" :changelog released-changelog)
      [code _] (cut dir "--next")]
  (check "next: exit" code 0)
  (check "next: version file" ((snapshot dir) 0) (string/format jdn-fixture "0.8.0-dev"))
  (check "next: changelog" ((snapshot dir) 1)
         (string "# Changelog\n\nintro\n\n## Unreleased\n\n" (string/slice released-changelog 20)))
  (check "next: readme untouched" ((snapshot dir) 2) readme-fixture)
  (cleanup dir))

(let [dir (fixture :version "0.7.0" :changelog released-changelog)
      [code _] (cut dir "--next" "1.0.0")]
  (check "next explicit: exit" code 0)
  (check "next explicit: version" ((snapshot dir) 0) (string/format jdn-fixture "1.0.0-dev"))
  (cleanup dir))

(refused "not main" "not on branch main" {:branch "topic"})
(refused "dirty tree" "not clean" {:dirty true})
(refused "not -dev" "does not end in -dev" {:version "0.7.0"})
(refused "empty unreleased" "is empty"
         {:changelog "# Changelog\n\n## Unreleased\n\n\n## 0.6.0\n\nx\n"})
(refused "no unreleased" "no ## Unreleased" {:changelog "# Changelog\n\n## 0.6.0\n\nx\n"})
(refused "existing section" "already has a section"
         {:changelog "# Changelog\n\n## Unreleased\n\n- x\n\n## 0.7.0\n\nx\n"})
(refused "bad version" "must be N.N.N" {} ["1.2"])
(refused "--next on -dev" "not a plain" {} ["--next"])

(if (zero? failures)
  (print "release cut tests: ok")
  (do (eprintf "release cut tests: %d failure(s)" failures) (os/exit 1)))
