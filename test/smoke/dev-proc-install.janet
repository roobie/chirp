# `chirp --dev-proc --install` in throwaway directories: the layout, the
# refusals that protect edits, and that the installed skill runs on its own.
(import spork/sh)

(def windows? (truthy? (index-of (os/which) [:windows :mingw])))
(def skill "dev-proc")

(defn- walk [dir &opt prefix]
  (default prefix "")
  (def out @[])
  (each name (os/dir dir)
    (if (= :directory (os/stat (string dir "/" name) :mode))
      (array/concat out (walk (string dir "/" name) (string prefix name "/")))
      (array/push out (string prefix name))))
  (sorted out))

# run changes directory, so a relative path to the binary would stop working.
(def exe
  (let [e (dyn *executable*)
        [ok p] (protect (os/realpath e))]
    (if ok p (string (os/cwd) "/" e))))

(defn- run
  "Run the binary under test in dir. Returns [exit stdout stderr], carriage
  returns removed."
  [dir env & args]
  (def before (os/cwd))
  (os/cd dir)
  (defer (os/cd before)
    # :e replaces the environment, so the overrides go on top of ours.
    (def p (os/spawn [exe ;args] :pe (merge (os/environ) env {:out :pipe :err :pipe})))
    (def [out err]
      (try (ev/with-deadline 60 (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
        ([_] (os/proc-kill p true) [nil "killed after 60s"])))
    [(os/proc-wait p)
     (string/replace-all "\r" "" (string out))
     (string/replace-all "\r" "" (string err))]))

(defn- tmpdir [tag]
  (def d (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                 "/chirp-smoke-" tag "-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs d)
  d)

(defn main [&]
  (def here (let [f (dyn *current-file*)]
              (string/slice f 0 (+ 1 (last (string/find-all "/" f))))))
  (def source (string here "../../.claude/skills/" skill))
  (def shipped (filter |(not (string/has-suffix? ".test.janet" $)) (walk source)))
  (assert (not (empty? shipped)) "no skill files found in the repo")

  (def tmp (tmpdir "dev-proc"))
  (defer (sh/rm tmp)
    (def no-env {})
    (defn same-as-source? [dir]
      (and (deep= (tuple ;shipped) (tuple ;(walk dir)))
           (all |(= (string (slurp (string source "/" $))) (string (slurp (string dir "/" $)))) shipped)))
    (defn exits [what want [code out err]]
      (assert (= want code) (string what ": exit " code " " (string/format "%q" (string out err))))
      (string out err))

    # Usage alone, and bad options.
    (exits "usage" 0 (run tmp no-env "--dev-proc"))
    (exits "unknown option" 2 (run tmp no-env "--dev-proc" "--install" "--bogus"))
    (exits "no --install" 2 (run tmp no-env "--dev-proc" "-g"))

    # Fresh install.
    (def proj (string tmp "/proj"))
    (sh/create-dirs proj)
    (exits "install" 0 (run proj no-env "--dev-proc" "--install"))
    (def canon (string proj "/.agents/skills/" skill))
    (def agent (string proj "/.claude/skills/" skill))
    (assert (same-as-source? canon) "canonical copy differs from the repo's skill")
    (assert (not (find |(string/has-suffix? ".test.janet" $) (walk canon))) "dev tests were shipped")
    (if windows?
      (assert (os/stat agent) "no agent copy (link or fallback)")
      (do
        (assert (= :link (os/lstat agent :mode)) "agent dir is not a link")
        (assert (= (string "../../.agents/skills/" skill) (os/readlink agent))
                (string "link target " (os/readlink agent)))
        (assert (= (os/realpath canon) (os/realpath agent)) "link does not resolve to the canonical dir")))

    # The installed skill runs with nothing else present.
    # dev-proc keeps its .work/ at the top of a git repository.
    (assert (= 0 (os/execute ["git" "init" "-q" proj] :p)) "git init failed")
    (def script (string ".claude/skills/" skill "/scripts/dev-proc.janet"))
    (exits "dev-proc init" 0 (run proj no-env script "init"))
    (exits "dev-proc status" 0 (run proj no-env script "status"))

    # Again: nothing to do. Edited: refused until --force. Extra files stay.
    (assert (string/find "up to date" (exits "reinstall" 0 (run proj no-env "--dev-proc" "--install")))
            "re-install did not say up to date")
    (def edited (string canon "/SKILL.md"))
    (def original (slurp edited))
    (spit edited (string original "\nmine\n"))
    (spit (string canon "/notes.md") "mine")
    (def refused (exits "modified" 1 (run proj no-env "--dev-proc" "--install")))
    (assert (and (string/find "SKILL.md" refused) (string/find "notes.md" refused)) refused)
    (assert (string/has-suffix? "\nmine\n" (string (slurp edited))) "refusal still changed the file")
    (exits "force" 0 (run proj no-env "--dev-proc" "--install" "--force"))
    (assert (= (string original) (string (slurp edited))) "--force did not restore the file")
    (assert (os/stat (string canon "/notes.md")) "--force removed an extra file")

    # A foreign directory in the agent location is never replaced.
    (def foreign (string tmp "/foreign"))
    (sh/create-dirs (string foreign "/.claude/skills/" skill))
    (spit (string foreign "/.claude/skills/" skill "/mine.txt") "mine")
    (def skipped (exits "foreign dir" 1 (run foreign no-env "--dev-proc" "--install" "--force")))
    (assert (string/find "skipped" skipped) skipped)
    (assert (deep= ["mine.txt"] (tuple ;(walk (string foreign "/.claude/skills/" skill)))) "foreign dir was touched")

    # --copy: real directory, no canonical dir.
    (def copy (string tmp "/copy"))
    (sh/create-dirs copy)
    (exits "copy" 0 (run copy no-env "--dev-proc" "--install" "--copy"))
    (assert (not (os/stat (string copy "/.agents"))) "--copy made a canonical dir")
    (assert (= :directory (os/lstat (string copy "/.claude/skills/" skill) :mode)) "--copy made no real dir")
    (assert (same-as-source? (string copy "/.claude/skills/" skill)) "--copy files differ")

    # -g goes under HOME (USERPROFILE on Windows).
    (def home (string tmp "/home"))
    (sh/create-dirs home)
    (exits "global" 0 (run proj {"HOME" home "USERPROFILE" home} "--dev-proc" "--install" "-g"))
    (assert (same-as-source? (string home "/.agents/skills/" skill)) "-g copy differs"))
  (print "ok dev-proc-install"))
