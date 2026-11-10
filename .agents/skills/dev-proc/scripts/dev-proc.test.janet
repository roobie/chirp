#!/usr/bin/env chirp
# Run: chirp dev-proc.test.janet   (exits non-zero on failure)
(import spork/json)
(import spork/sh)

(def cli
  (let [file (dyn :current-file)
        abs (if (string/has-prefix? "/" file) file (string (os/cwd) "/" file))]
    (string (string/slice abs 0 (last (string/find-all "/" abs))) "/dev-proc.janet")))

(var failures 0)

(defn test [name thunk]
  (def r (protect (thunk)))
  (unless (r 0)
    (++ failures)
    (eprint "FAIL " name ": " (string (r 1)))))

(defn check [ok &opt msg] (unless ok (error (or msg "assertion failed"))))
(defn matches [pattern text] (check (peg/match pattern text) (string "no match for " (string/format "%q" text))))

(def DEADLINE 60)

# Runs the CLI in `cwd`; returns {:status :stdout :stderr}.
(defn run-with [opts cwd & args]
  (def old (os/cwd))
  (os/cd cwd)
  (defer (os/cd old)
    (def env (opts :env))
    (def p (os/spawn [(dyn :executable) cli ;args] (if env :pe :p)
                     (merge (or env {}) {:out :pipe :err :pipe} (if (opts :in) {:in :pipe} {}))))
    (when (opts :in)
      (ev/write (p :in) (opts :in))
      (:close (p :in)))
    # A run that hangs (a fifo opened for reading, say) fails the test instead of the whole suite.
    (def [o e] (try (ev/with-deadline DEADLINE (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
                 ([_] (os/proc-kill p) (error (string "no answer within " DEADLINE "s: " (string/join args " "))))))
    {:status (os/proc-wait p) :stdout (string (or o "")) :stderr (string (or e ""))}))

(defn run [cwd & args] (run-with {} cwd ;args))

(defn tmp-dir []
  (def hex (string/join (map |(string/format "%02x" $) (os/cryptorand 6))))
  (def dir (string (or (os/getenv "TMPDIR") "/tmp") "/dev-proc-test-" hex))
  (os/mkdir dir)
  dir)

# A throwaway git repo with an initialised .work/ and two durable records.
(defn scratch-repo []
  (def dir (tmp-dir))
  (def git (os/spawn ["git" "-C" dir "init" "-q"] :p))
  (check (= 0 (os/proc-wait git)) "git init failed")
  (check (= 0 ((run dir "init") :status)))
  (defn rec [kind & args]
    (def r (run dir "record" kind ;args))
    (check (= 0 (r :status)) (r :stderr)))
  (rec "decision" "Shaders come from Slang" "--read-if" "changing a shader" "--read-if" "adding a render pipeline")
  (rec "learning" "Bench threads are noisy" "--read-if" "running the bench [threads]")
  dir)

(defn with-repo [f]
  (def dir (scratch-repo))
  (defer (sh/rm dir) (f dir)))

(test "--help and -h print usage"
  (fn []
    (def dir (tmp-dir))
    (defer (sh/rm dir)
      (each flag ["--help" "-h"]
        (def r (run dir flag))
        (check (= 0 (r :status)))
        (check (string/find "find <words…>" (r :stdout)))))))

(test "find --help and find -h print the find usage"
  (fn []
    (with-repo
      (fn [dir]
        (each flag ["--help" "-h"]
          (def r (run dir "find" flag))
          (check (= 0 (r :status)))
          (check (string/has-prefix? "usage: find <words…>" (r :stdout))))))))

(test "find lists matching records with their cues, as text and JSON"
  (fn []
    (with-repo
      (fn [dir]
        (def text (run dir "find" "changing" "a" "shader"))
        (check (= 0 (text :status)))
        (matches ~(* "D-" (16 (+ (range "AZ") (range "27"))) "  Shaders come from Slang\n    read if: changing a shader\n" -1)
                 (text :stdout))
        (def hits (json/decode (string ((run dir "find" "changing a shader" "--json") :stdout))))
        (check (= 1 (length hits)))
        (check (deep= (get-in hits [0 "cues"]) @["changing a shader"]))
        (check (= "decision" (get-in hits [0 "kind"])))
        (check (string/find "no decisions or learnings match \"xyzzy\"" ((run dir "find" "xyzzy") :stdout)))
        (check (= 2 ((run dir "find") :status)))))))

(test "a read_if with brackets is recorded, then passes check and is found"
  (fn []
    (with-repo
      (fn [dir]
        (def c (run dir "check"))
        (check (= 0 (c :status)) (string (c :stdout) (c :stderr)))
        (check (string/find "read if: running the bench [threads]" ((run dir "find" "bench") :stdout)))))))

(test "status prints the find hint on the counts line, not in JSON"
  (fn []
    (with-repo
      (fn [dir]
        (check (string/has-suffix? "learnings: 1 (find \"<topic>\" lists the ones to read)\n" ((run dir "status") :stdout)))
        (check (not (string/find "find \"<topic>\"" ((run dir "status" "--json") :stdout))))))))

(test "values that need YAML quoting are written quoted and read back"
  (fn []
    (with-repo
      (fn [dir]
        (def r (run dir "record" "learning" "Colon cue" "--read-if" "x: y" "--read-if" "`tick` # hash" "--read-if" "true"))
        (check (= 0 (r :status)) (r :stderr))
        (def c (run dir "check"))
        (check (= 0 (c :status)) (string (c :stdout) (c :stderr)))
        (def hits (json/decode (string ((run dir "find" "colon" "--json") :stdout))))
        (check (deep= (get-in hits [0 "readIf"]) @["x: y" "`tick` # hash" "true"]) (string/format "%q" hits))))))

(test "check reports a front matter value that is not a string or list"
  (fn []
    (with-repo
      (fn [dir]
        (def file (string dir "/.work/decisions/" (first (filter |(string/has-prefix? "D-" $) (os/dir (string dir "/.work/decisions"))))))
        (spit file (string/replace "read_if:" "read_if:\n  - text: more\nbad: 3\nold:" (string (slurp file))))
        (def c (run dir "check"))
        (check (not= 0 (c :status)))
        (check (string/find "key \"read_if\"" (string (c :stdout) (c :stderr))) (string (c :stdout) (c :stderr)))))))

(test "dates follow the local calendar day, not UTC"
  (fn []
    (with-repo
      (fn [dir]
        # POSIX zones 26 hours apart can never share a calendar day, whereas UTC would.
        (defn created-in [tz]
          (def r (run-with {:env {"TZ" tz}} dir "record" "backlog" (string "in " tz)))
          (check (= 0 (r :status)) (r :stderr))
          (def file (string dir "/" (last (string/split " " (string/trim (r :stdout))))))
          (last (string/split ": " (first (filter |(string/has-prefix? "created:" $) (string/split "\n" (string (slurp file))))))))
        (check (not= (created-in "UTC-14") (created-in "UTC+12")))))))

(test "new and record print just the id with --id and one JSON object with --json"
  (fn []
    (with-repo
      (fn [dir]
        (def u (run dir "new" "task" "alpha" "--id"))
        (check (= 0 (u :status)) (u :stderr))
        (matches ~(* "U-" (16 (+ (range "AZ") (range "27"))) "\n" -1) (u :stdout))
        (def uj (json/decode (string ((run dir "new" "task" "beta" "--json") :stdout))))
        (check (and (= "task/beta" (uj "label")) (= "task" (uj "type")) (= "beta" (uj "name"))))
        (check (string/has-suffix? (string "-beta") (uj "path")))
        (check (os/stat (string dir "/" (uj "path") "/STATE.md")))
        (def r (run dir "record" "learning" "Json learning" "--json"))
        (def rj (json/decode (string (r :stdout))))
        (check (and (= "learning" (rj "kind")) (string/has-suffix? ".md" (rj "path"))))
        (check (os/stat (string dir "/" (rj "path"))))
        (matches ~(* "L-" (16 (+ (range "AZ") (range "27"))) "\n" -1) ((run dir "record" "learning" "Id only" "--id") :stdout))
        # default output is unchanged
        (matches ~(* "created U-" (16 (+ (range "AZ") (range "27"))) " task/gamma: ") ((run dir "new" "task" "gamma") :stdout))))))

(defn unit-file [dir lbl]
  (def [type name] (string/split "/" lbl))
  (def j (json/decode (string ((run dir "status" lbl "--json") :stdout))))
  (string dir "/.work/" type "/" (j "id") "-" name "/STATE.md"))

(defn read-unit [dir lbl] (string (slurp (unit-file dir lbl))))

(test "new fills criteria and purpose, and --execute passes the gate in the same call"
  (fn []
    (with-repo
      (fn [dir]
        (def r (run dir "new" "slice" "fast" "--owner" "BR,claude" "--criterion" "first holds" "--criterion" "second: holds"
                    "--purpose" "Because speed." "--execute"))
        (check (= 0 (r :status)) (r :stderr))
        (check (string/find "initialize → execute" (r :stdout)))
        (def j (json/decode (string ((run dir "status" "slice/fast" "--json") :stdout))))
        (check (= "execute" (j "mode")))
        (check (deep= (j "success_criteria") @["first holds" "second: holds"]))
        (def text (read-unit dir "slice/fast"))
        (check (string/find "## Purpose\nBecause speed.\n\n## Scope" text) text)
        (check (not (string/find "TODO: why this unit exists" text)))
        (def c (run dir "check"))
        (check (= 0 (c :status)) (string (c :stdout) (c :stderr)))))))

(test "new --execute without owner or criteria fails cleanly but keeps the unit"
  (fn []
    (with-repo
      (fn [dir]
        (def r (run dir "new" "task" "bare" "--execute"))
        (check (not= 0 (r :status)))
        (check (string/find "gate → execute closed" (r :stderr)))
        (check (string/find "owner is empty" (r :stderr)))
        (check (string/find "success_criteria is empty" (r :stderr)))
        (check (string/find "created U-" (r :stdout)))
        (def j (json/decode (string ((run dir "status" "task/bare" "--json") :stdout))))
        (check (= "initialize" (j "mode")))))))

(test "new and record take a body split by ## headings, from a file or stdin"
  (fn []
    (with-repo
      (fn [dir]
        (def body "## Context\nBecause of **x**.\n\n## Why\nOnly reason.\n")
        (spit (string dir "/body.md") body)
        (def r (run dir "record" "decision" "From file" "--read-if" "cue" "--body-file" "body.md" "--json"))
        (check (= 0 (r :status)) (r :stderr))
        (def text (string (slurp (string dir "/" ((json/decode (string (r :stdout))) "path")))))
        (check (string/find "## Context\nBecause of **x**.\n\n## Decision\nTODO" text) text)
        (check (string/find "## Why\nOnly reason.\n\n## Consequences\nTODO" text) text)
        (def s (run-with {:in "## Purpose\nFrom stdin.\n\n## Scope\nIn: this\n```\n## not a heading\n```\n"}
                        dir "new" "task" "piped" "--body" "-"))
        (check (= 0 (s :status)) (s :stderr))
        (def st (read-unit dir "task/piped"))
        (check (string/find "## Purpose\nFrom stdin.\n\n## Scope\nIn: this\n```\n## not a heading\n```\n\n## Context" st) st)))))

(test "an unknown or repeated heading in a body is an error that leaves nothing behind"
  (fn []
    (with-repo
      (fn [dir]
        (def r (run-with {:in "## Nonsense\nx\n"} dir "record" "learning" "Bad" "--body" "-"))
        (check (not= 0 (r :status)))
        (check (string/find "valid: Observation, Why it matters" (r :stderr)) (r :stderr))
        (check (= 1 (length (os/dir (string dir "/.work/learnings")))))
        (def p (run-with {:in "## Purpose\nx\n"} dir "new" "task" "dup" "--purpose" "y" "--body" "-"))
        (check (not= 0 (p :status)))
        (check (not (os/stat (string dir "/.work/task"))))
        (def t (run-with {:in "text first\n## Purpose\nx\n"} dir "new" "task" "dup" "--body" "-"))
        (check (string/find "must start with" (t :stderr)))))))

(test "a body keeps the lints of durable records"
  (fn []
    (with-repo
      (fn [dir]
        (def r (run-with {:in "## Observation\nsee:\n```\ncode\n```\n"} dir "record" "learning" "Has code" "--read-if" "x" "--body" "-"))
        (check (= 0 (r :status)) (r :stderr))
        (check (string/find "code block in a durable doc" ((run dir "check") :stdout)))))))

(test "new --from keeps the origin when the body replaces the context section"
  (fn []
    (with-repo
      (fn [dir]
        (def b (string/trim ((run dir "record" "backlog" "Later" "--id") :stdout)))
        (def r (run-with {:in "## Context & constraints\nMine.\n"} dir "new" "task" "from-b" "--from" b "--body" "-"))
        (check (= 0 (r :status)) (r :stderr))
        (def st (read-unit dir "task/from-b"))
        (check (string/find "Mine.\n\n### Origin\nPromoted from backlog: " st) st)
        (check (string/find " Later\n\n### Why" st) st)
        (check (not (string/find "<!-- origin -->" st)))))))

(defn git-in [dir & args]
  (def p (os/spawn ["git" "-C" dir ;args] :p {:out :pipe :err :pipe}))
  (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all))
  (check (= 0 (os/proc-wait p)) (string "git " (string/join args " ") " failed")))

(defn new-id [dir & args]
  (def r (run dir "new" ;args "--id" "--owner" "BR" "--criterion" "done"))
  (check (= 0 (r :status)) (r :stderr))
  (string/trim (r :stdout)))

(test "trailers lists the staged units, most specific first"
  (fn []
    (with-repo
      (fn [dir]
        (def slice (new-id dir "slice" "outer" "--execute"))
        (def task (new-id dir "task" "inner" "--parent" slice "--execute"))
        (git-in dir "add" ".work")
        (def r (run dir "trailers"))
        (check (= 0 (r :status)) (r :stderr))
        (check (= (string "Work: " task "\nWork: " slice "\n") (r :stdout)) (r :stdout))
        (check (= "" (r :stderr)) (r :stderr))
        # the output satisfies the commit-msg check
        (spit (string dir "/msg") (string "x\n\n" (r :stdout)))
        (check (= "" ((run dir "check-msg" "msg") :stdout)))))))

(test "trailers warns which STATE.md would satisfy the pre-commit check"
  (fn []
    (with-repo
      (fn [dir]
        (def slice (new-id dir "slice" "outer" "--execute"))
        (spit (string dir "/code.txt") "x\n")
        (git-in dir "add" "code.txt")
        (def r (run dir "trailers"))
        (check (= 0 (r :status)))
        (check (= "" (r :stdout)))
        (check (string/find (string ".work/slice/" slice "-outer/STATE.md") (r :stderr)) (r :stderr))
        (check (string/find "no STATE.md is" (r :stderr)))
        (git-in dir "add" ".work")
        (check (= "" ((run dir "trailers") :stderr)))))))

(defn note-test [f]
  (with-repo
    (fn [dir]
      (new-id dir "task" "noted")
      (f dir (unit-file dir "task/noted")))))

(test "note replaces Now and Next and appends to Evidence, Harvest and Log"
  (fn []
    (note-test
      (fn [dir file]
        (defn note [& args] (def r (run dir "note" "task/noted" ;args)) (check (= 0 (r :status)) (r :stderr)))
        (note "now" "doing" "it")
        (note "next" "- one\n- two")
        (note "evidence" "tests pass")
        (note "evidence" "and again")
        (note "harvest" "backlog: later")
        (note "log" "a thing happened")
        (def text (string (slurp file)))
        (check (string/find "## Now\ndoing it\n\n## Next\n- one\n- two\n\n## Evidence\n" text) text)
        (check (string/find "-->\n- tests pass\n- and again\n\n## Harvest" text) text)
        (check (string/find "-->\n- [ ] backlog: later\n\n## Log\n- " text) text)
        (check (peg/match ~(* (thru "initialized\n- ") (repeat 4 :d) "-" (repeat 2 :d) "-" (repeat 2 :d) " a thing happened\n" -1) text) text)
        (def c (run dir "check"))
        (check (= 0 (c :status)) (string (c :stdout) (c :stderr)))
        # an open Harvest item blocks close, as it would by hand
        (check (string/find "1 unchecked" ((run dir "close" "task/noted") :stderr)))))))

(test "note preserves text beginning with -- after the terminator"
  (fn []
    (note-test
      (fn [dir file]
        (def r (run dir "note" "task/noted" "log" "--" "--force was needed"))
        (check (= 0 (r :status)) (r :stderr))
        (check (string/find "--force was needed" (slurp file)) (slurp file))))))

(test "note rejects an unknown section and empty text"
  (fn []
    (note-test
      (fn [dir _]
        (check (string/find "usage: note" ((run dir "note" "task/noted" "purpose" "x") :stderr)))
        (check (string/find "needs text" ((run dir "note" "task/noted" "now") :stderr)))
        (check (string/find "no active unit" ((run dir "note" "task/none" "now" "x") :stderr)))))))

(defn ok [r] (check (= 0 (r :status)) (string (r :stdout) (r :stderr))) r)

(test "dev-proc.root outside the repo is used, covered by find and check, and kept out of commits"
  (fn []
    (with-repo
      (fn [dir]
        (def mine (tmp-dir))
        (defer (sh/rm mine)
          (def root (string mine "/my-work"))
          (git-in dir "config" "dev-proc.root" root)
          (check (string/find (string "dev-proc.root is " root) ((run dir "status") :stderr)))
          (check (string/find root ((ok (run dir "init")) :stdout)))
          (check (os/stat (string root "/.gitkeep")))
          (check (not (os/stat (string dir "/.work/task"))))
          (def task (new-id dir "task" "private" "--execute"))
          (check (os/stat (string root "/task/" task "-private/STATE.md")))
          (def s (ok (run dir "status")))
          (check (string/has-prefix? (string "root: " root "  (out-of-band)\n") (s :stdout)) (s :stdout))
          (check (string/find task (s :stdout)))
          # refs resolve against the repo, and find sees the team's records and mine
          (spit (string dir "/code.txt") "defn thing\n")
          (ok (run dir "record" "decision" "Private shader call" "--read-if" "changing a shader privately" "--ref" "code.txt#thing"))
          (ok (run dir "check"))
          (def hits (json/decode (string ((run dir "find" "changing a shader" "--json") :stdout))))
          (check (= 2 (length hits)) (string/format "%q" hits))
          (check (find |(= root ($ "root")) hits))
          # code staged in the repo neither asks for nor names the private unit
          (git-in dir "add" "code.txt")
          (def t (ok (run dir "trailers")))
          (check (= "" (t :stdout) (t :stderr)) (string (t :stdout) (t :stderr)))
          (def h (ok (run-with {:env {"DEV_PROC_STRICT" "1" "PATH" (os/getenv "PATH")}} dir "check" "--staged" "--hook")))
          (check (not (string/find "STATE.md" (h :stdout))) (h :stdout))
          (check (not (string/find root (h :stdout))) (h :stdout))
          (spit (string dir "/msg") "x\n")
          (check (= "" ((run dir "check-msg" "msg") :stdout)))
          # --root still reaches the team's tree
          (check (string/has-prefix? "root: .work\n" ((ok (run dir "status" "--root" ".work")) :stdout)))
          # closing names no trailer to put in a team commit
          (ok (run dir "phase" task "finalize"))
          (def c (ok (run dir "close" task)))
          (check (not (string/find "Work:" (c :stdout))) (c :stdout))
          (check (not (os/stat (string root "/task/" task "-private")))))))))

(test "dev-proc.root inside the repo takes any name, and check warns unless it is ignored"
  (fn []
    (with-repo
      (fn [dir]
        (git-in dir "config" "dev-proc.root" ".mine")
        (ok (run dir "init"))
        (new-id dir "task" "private" "--execute")
        (check (string/has-prefix? "root: .mine  (out-of-band)\n" ((ok (run dir "status")) :stdout)))
        (check (string/find ".mine: out-of-band root is inside the repo but not git-ignored" ((run dir "check") :stdout)))
        (spit (string dir "/.git/info/exclude") ".mine/\n")
        (check (not (string/find "out-of-band" ((ok (run dir "check")) :stdout))))
        # from a subdirectory too
        (os/mkdir (string dir "/sub"))
        (check (string/has-prefix? "root: .mine  (out-of-band)\n" ((ok (run (string dir "/sub") "status")) :stdout)))))))

# Closes a unit and supersedes a decision in the configured root; returns [task-id old-decision-id].
(defn close-and-supersede [dir]
  (def task (new-id dir "task" "private" "--execute"))
  (ok (run dir "phase" task "finalize"))
  (def old (string/trim ((ok (run dir "record" "decision" "Old call" "--read-if" "x" "--id")) :stdout)))
  [task old])

(test "a root without git history keeps closed units and superseded records in closed/"
  (fn []
    (with-repo
      (fn [dir]
        (def mine (tmp-dir))
        (defer (sh/rm mine)
          (def root (string mine "/w"))
          (git-in dir "config" "dev-proc.root" root)
          (ok (run dir "init"))
          (def [task old] (close-and-supersede dir))
          (def c (ok (run dir "close" task)))
          (check (string/find (string "moved " task) (c :stdout)) (c :stdout))
          (check (not (string/find "Work:" (c :stdout))) (c :stdout))
          (check (os/stat (string root "/closed/task/" task "-private/STATE.md")))
          (def r (ok (run dir "record" "decision" "New call" "--read-if" "x" "--supersedes" old)))
          (check (not (string/find "Supersedes:" (r :stdout))) (r :stdout))
          (check (= 1 (length (filter |(string/has-prefix? old $) (os/dir (string root "/closed/decisions"))))))
          (check (empty? (filter |(string/has-prefix? old $) (os/dir (string root "/decisions")))))
          # closed/ is out of view, but dig reads it
          (def s (ok (run dir "status")))
          (check (not (string/find task (s :stdout))) (s :stdout))
          (ok (run dir "check"))
          (check (empty? (json/decode (string ((ok (run dir "find" "Old" "--json")) :stdout)))))
          (def d (ok (run dir "dig" task)))
          (check (string/find "# task/private" (d :stdout)) (d :stdout))
          (check (string/find "# D-" ((ok (run dir "dig" old)) :stdout)))
          (check (string/find "no closed copy" ((run dir "dig" "U-AAAAAAAAAAAAAAAA") :stderr))))))))

(test "a git-ignored root in the repo has no history; one in a repo of its own does"
  (fn []
    (with-repo
      (fn [dir]
        (git-in dir "config" "dev-proc.root" ".mine")
        (spit (string dir "/.git/info/exclude") ".mine/\n")
        (ok (run dir "init"))
        (def [task _] (close-and-supersede dir))
        (ok (run dir "close" task))
        (check (os/stat (string dir "/.mine/closed/task/" task "-private")))))
    (with-repo
      (fn [dir]
        (def mine (tmp-dir))
        (defer (sh/rm mine)
          (git-in mine "init" "-q")
          (git-in dir "config" "dev-proc.root" mine)
          (ok (run dir "init"))
          (def [task old] (close-and-supersede dir))
          (def c (ok (run dir "close" task)))
          (check (string/find "deleted" (c :stdout)) (c :stdout))
          (check (not (os/stat (string mine "/closed"))))
          (def r (ok (run dir "record" "decision" "New call" "--read-if" "x" "--supersedes" old)))
          (check (not (string/find "Supersedes:" (r :stdout))) (r :stdout))
          (check (not (os/stat (string mine "/closed")))))))))

(test "outside a git repo the unit and record commands work against the nearest work dir"
  (fn []
    (def dir (tmp-dir))
    (defer (sh/rm dir)
      (check (string/find "found from here up to /" ((run dir "status") :stderr)))
      (ok (run dir "init"))
      (check (os/stat (string dir "/.work/.gitkeep")))
      (os/mkdir (string dir "/sub"))
      (def sub (string dir "/sub"))
      (def task (new-id sub "task" "loose" "--execute"))
      (check (os/stat (string dir "/.work/task/" task "-loose/STATE.md")))
      (ok (run sub "note" task "now" "working"))
      (ok (run sub "rescope" task "--name" "looser"))
      (def s (ok (run sub "status")))
      (check (string/has-prefix? "root: .work\n" (s :stdout)) (s :stdout))
      (check (string/find "task/looser" (s :stdout)) (s :stdout))
      # refs resolve against the work dir's parent
      (spit (string dir "/code.txt") "defn thing\n")
      (def old (string/trim ((ok (run sub "record" "decision" "Loose call" "--read-if" "loose work" "--ref" "code.txt#thing" "--id")) :stdout)))
      (ok (run sub "check"))
      (check (string/find old ((ok (run sub "find" "loose work")) :stdout)))
      (ok (run sub "record" "decision" "Looser call" "--read-if" "x" "--supersedes" old))
      (check (string/find old ((ok (run sub "dig" old)) :stdout)))
      # no history, so close keeps the unit and names no trailer
      (ok (run sub "phase" task "finalize"))
      (def c (ok (run sub "close" task)))
      (check (not (string/find "Work:" (c :stdout))) (c :stdout))
      (check (os/stat (string dir "/.work/closed/task/" task "-looser/STATE.md")))
      (check (string/find "# task/looser" ((ok (run sub "dig" task)) :stdout)))
      # --root reaches a work dir elsewhere
      (def other (tmp-dir))
      (defer (sh/rm other)
        (ok (run other "init"))
        (new-id other "task" "elsewhere")
        (check (string/find "task/elsewhere" ((ok (run sub "status" "--root" (string other "/.work"))) :stdout)))))))

(test "outside a git repo the git-only commands say they need git"
  (fn []
    (def dir (tmp-dir))
    (defer (sh/rm dir)
      (ok (run dir "init"))
      (spit (string dir "/msg") "x\n")
      (each args [["trailers"] ["check-msg" "msg"] ["hooks" "install"] ["report"] ["check" "--staged"]]
        (def r (run dir ;args))
        (check (not= 0 (r :status)) (string/join args " "))
        (check (string/find "needs a git repository" (r :stderr)) (r :stderr)))
      (check (not (os/stat (string dir "/.git")))))))

(test "outside a git repo a global dev-proc.root is not used"
  (fn []
    (def dir (tmp-dir))
    (def home (tmp-dir))
    (defer (do (sh/rm dir) (sh/rm home))
      (spit (string home "/.gitconfig") (string "[dev-proc]\n\troot = " home "/mine\n"))
      (def env {"HOME" home "PATH" (os/getenv "PATH")})
      (ok (run-with {:env env} dir "init"))
      (check (os/stat (string dir "/.work")))
      (check (not (os/stat (string home "/mine")))))))

(test "DEV_PROC_ROOT is the default for --root, in and out of a git repo"
  (fn []
    (def plain (tmp-dir))
    (def mine (tmp-dir))
    (defer (do (sh/rm plain) (sh/rm mine))
      (def root (string mine "/.mine"))
      (defn env [v] {:env {"DEV_PROC_ROOT" v "PATH" (os/getenv "PATH") "HOME" (os/getenv "HOME")}})
      (check (string/find "DEV_PROC_ROOT is " ((run-with (env root) plain "status") :stderr)))
      (ok (run-with (env root) plain "init"))
      (check (os/stat (string root "/.gitkeep")))
      (check (not (os/stat (string plain "/.work"))))
      (ok (run plain "init"))
      (new-id plain "task" "elsewhere")
      (def t (string/trim ((ok (run-with (env root) plain "new" "task" "pinned" "--id")) :stdout)))
      (check (os/stat (string root "/task/" t "-pinned/STATE.md")))
      (check (string/find "task/pinned" ((ok (run-with (env root) plain "status")) :stdout)))
      # --root on the command line wins
      (def s (ok (run-with (env root) plain "status" "--root" (string plain "/.work"))))
      (check (string/find "task/elsewhere" (s :stdout)) (s :stdout))
      (check (not (string/find "task/pinned" (s :stdout))) (s :stdout))
      # in a git repo it comes before the nearest .work/
      (with-repo
        (fn [dir]
          (def r (ok (run-with (env root) dir "status")))
          (check (string/find "task/pinned" (r :stdout)) (r :stdout))))
      # a relative value is refused: it would mean something else in each subdirectory
      (def r (run-with (env ".mine") mine "status"))
      (check (not= 0 (r :status)))
      (check (string/find "not an absolute path" (r :stderr)) (r :stderr)))))

(test "dev-proc.root expands ~"
  (fn []
    (with-repo
      (fn [dir]
        (def home (tmp-dir))
        (defer (sh/rm home)
          (def env {"HOME" home "PATH" (os/getenv "PATH")})
          (git-in dir "config" "dev-proc.root" "~/notes/work")
          (ok (run-with {:env env} dir "init"))
          (check (os/stat (string home "/notes/work/.gitkeep"))))))))

(test ".dev-proc.toml work_dir renames the work dir of its own directory only"
  (fn []
    (with-repo
      (fn [dir]
        (spit (string dir "/.dev-proc.toml") "work_dir = \".tasks\"\n")
        (check (string/find "created .tasks/" ((ok (run dir "init")) :stdout)))
        (def task (new-id dir "task" "renamed" "--execute"))
        (check (os/stat (string dir "/.tasks/task/" task "-renamed/STATE.md")))
        (check (string/has-prefix? "root: .tasks\n" ((ok (run dir "status")) :stdout)))
        # the old .work beside it is no longer read, and check says so
        (def c (ok (run dir "check")))
        (check (string/find ".work: not read, since .dev-proc.toml names .tasks" (c :stdout)) (c :stdout))
        (check (string/find "no decisions or learnings match" ((run dir "find" "changing a shader") :stdout)))
        # the hooks and trailers follow the renamed dir
        (git-in dir "add" ".tasks" ".dev-proc.toml")
        (check (= (string "Work: " task "\n") ((ok (run dir "trailers")) :stdout)))
        # a subdirectory keeps .work unless it has a file of its own
        (os/mkdir (string dir "/sub"))
        (ok (run (string dir "/sub") "init" "."))
        (check (os/stat (string dir "/sub/.work/.gitkeep")))
        (spit (string dir "/sub/.dev-proc.toml") "# sub's own\nwork_dir = \"_w\"\n")
        (ok (run (string dir "/sub") "init"))
        (check (string/has-prefix? "root: sub/_w\n" ((ok (run (string dir "/sub") "status")) :stdout)))
        (check (string/find "sub/.work: not read" ((run dir "check") :stdout)))))))

(test "a bad .dev-proc.toml is an error naming it, and an empty one means .work"
  (fn []
    (with-repo
      (fn [dir]
        (def file (string dir "/.dev-proc.toml"))
        (each [text want] [["work_dir = \"a/b\"\n" "work_dir must be one directory name"]
                           ["work_dir = \"..\"\n" "work_dir must be one directory name"]
                           ["work_dir = 3\n" "work_dir must be one directory name"]
                           ["workdir = \".x\"\n" "unknown key \"workdir\""]
                           ["work_dir = \n" "input is not valid TOML"]]
          (spit file text)
          # a command on one root stops; the sweep reports it and goes on
          (def r (run dir "status"))
          (check (not= 0 (r :status)) text)
          (check (string/find (string ".dev-proc.toml: " want) (r :stderr)) (r :stderr))
          (def c (run dir "check"))
          (check (not= 0 (c :status)) text)
          (check (string/find (string ".dev-proc.toml: " want) (c :stdout)) (c :stdout)))
        (spit file "")
        (check (string/has-prefix? "root: .work\n" ((ok (run dir "status")) :stdout)))))))

(test "a git-ignored .dev-proc.toml is skipped with a warning"
  (fn []
    (with-repo
      (fn [dir]
        (spit (string dir "/.dev-proc.toml") "work_dir = \".tasks\"\n")
        (spit (string dir "/.git/info/exclude") ".dev-proc.toml\n")
        (def s (ok (run dir "status")))
        (check (string/has-prefix? "root: .work\n" (s :stdout)) (s :stdout))
        (check (string/find ".dev-proc.toml is git-ignored, so it is skipped" (s :stderr)) (s :stderr))))))

(test "dig finds a record deleted before the work dir was renamed"
  (fn []
    (with-repo
      (fn [dir]
        (git-in dir "config" "user.name" "t")
        (git-in dir "config" "user.email" "t@example.invalid")
        (def b (string/trim ((ok (run dir "record" "backlog" "Gone soon" "--id")) :stdout)))
        (git-in dir "add" ".work")
        (git-in dir "commit" "-qm" "add")
        (git-in dir "rm" "-q" (string ".work/backlog/" (first (os/dir (string dir "/.work/backlog")))))
        (git-in dir "commit" "-qm" "drop")
        (git-in dir "mv" ".work" ".tasks")
        (spit (string dir "/.dev-proc.toml") "work_dir = \".tasks\"\n")
        (git-in dir "add" ".dev-proc.toml")
        (git-in dir "commit" "-qm" "rename")
        (def r (ok (run dir "dig" b)))
        (check (string/find (string "===== .work/backlog/" b "-gone-soon.md") (r :stdout)) (r :stdout))))))

(test "report sums up the units and records of a range, the last tag..HEAD by default"
  (fn []
    (with-repo
      (fn [dir]
        (git-in dir "config" "user.name" "t")
        (git-in dir "config" "user.email" "t@example.invalid")
        (defn commit [msg & ids]
          (git-in dir "add" "-A")
          (git-in dir "commit" "-qm" (string msg "\n\n" (string/join (map |(string "Work: " $) ids) "\n"))))
        (commit "base")
        (git-in dir "tag" "v1")
        (def s (new-id dir "slice" "outer" "--execute"))
        (def t (new-id dir "task" "done" "--parent" s "--execute"))
        (def x (new-id dir "task" "dropped" "--parent" s "--execute"))
        (def y (new-id dir "task" "moved" "--parent" s))
        (commit "start" t x y s)
        (ok (run dir "phase" t "finalize"))
        (ok (run dir "close" t))
        (commit "finish t" t)
        (def d (string/trim ((ok (run dir "record" "decision" "Why x stopped" "--read-if" "x" "--id")) :stdout)))
        (ok (run dir "phase" x "finalize"))
        (ok (run dir "close" x "--scrap" "--decision" d))
        (git-in dir "add" "-A")
        (git-in dir "commit" "-qm" (string "scrap x\n\nWork: " x "\nDecision: " d))
        (ok (run dir "rescope" y "--name" "renamed"))
        (commit "rescope y" y)
        (def r (ok (run dir "report")))
        (def lines (string/split "\n" (r :stdout)))
        (check (string/has-prefix? "v1..HEAD: 4 commits, " (lines 0)) (r :stdout))
        (check (= (string/slice (r :stdout) (length (lines 0)))
                  (string "\ndelivered\n  " t " task/done  2 commits  in slice/outer\n"
                          "scrapped\n  " x " task/dropped  2 commits  in slice/outer\n"
                          "open\n  " y " task/renamed  2 commits  new  in slice/outer\n"
                          "  " s " slice/outer  1 commit  new\n"
                          "records  decisions +1  learnings +0  backlog +0\n"))
               (r :stdout))
        # a revision means <rev>..HEAD; JSON carries the same
        (def j (json/decode (string ((ok (run dir "report" "HEAD~1" "--json")) :stdout))))
        (check (= "HEAD~1..HEAD" (j "range")))
        (check (= 1 (j "commits")))
        (check (deep= (j "units") @[@{"id" y "label" "task/renamed" "outcome" "open" "started" false "commits" 1
                                      "parent" s "parentLabel" "slice/outer"}])
               (string/format "%q" (j "units")))
        # without a tag it is all of HEAD's history, which holds the scratch records
        (git-in dir "tag" "-d" "v1")
        (check (string/find "decisions +2  learnings +1" ((ok (run dir "report")) :stdout)))
        (check (string/find "is it a range" ((run dir "report" "nope..HEAD") :stderr)))))))

# Adds a front matter line to a work file.
(defn add-front [file line]
  (spit file (string/replace "---\n" (string "---\n" line "\n") (string (slurp file)))))

(defn status-json [dir & args]
  (def r (run dir "status" ;args "--json"))
  (check (= 0 (r :status)) (r :stderr))
  (json/decode (r :stdout)))

(def date-peg (peg/compile ~(* (4 :d) "-" (2 :d) "-" (2 :d) -1)))
(defn date? [v] (and (string? v) (peg/match date-peg v)))

# {heading text} of the decoded sections, in their order, as [heading text] pairs.
(defn pairs-of [sections] (map |[($ "heading") ($ "text")] sections))
(defn text-of [sections heading] (get (find |(= ($ "heading") heading) sections) "text"))

(defn record-file [dir kind id]
  (def sub (string dir "/.work/" kind))
  (string sub "/" (find |(string/has-prefix? id $) (os/dir sub))))

(test "status <unit> --json gives the sections in document order, without the template's comments"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "new" "task" "page" "--purpose" "Show it.") :status)))
        (check (= 0 ((run dir "note" "task/page" "now" "Working.") :status)))
        (def out ((run dir "status" "task/page" "--json") :stdout))
        (def sections ((json/decode out) "sections"))
        (check (deep= (map |($ 0) (pairs-of sections))
                      @["Purpose" "Scope" "Context & constraints" "Now" "Next" "Evidence" "Harvest" "Log"]))
        (check (= "Show it." (text-of sections "Purpose")))
        (check (= "Working." (text-of sections "Now")))
        (check (= "" (text-of sections "Harvest")))
        (check (string/has-prefix? "- " (text-of sections "Log")))
        (check (not (string/find "<!--" out)))))))

(test "repeated headings, CRLF lines and fenced ## lines come through as separate, ordered sections"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "new" "task" "page") :status)))
        (def file (unit-file dir "task/page"))
        (spit file (string (string/replace-all "\n" "\r\n" (string (slurp file))) "\r\n## Log\r\nsecond\r\n```\r\n## not a heading\r\n```\r\n"))
        (def sections ((status-json dir "task/page") "sections"))
        (def logs (filter |(= "Log" ($ "heading")) sections))
        (check (= 2 (length logs)))
        (check (= "second\n```\n## not a heading\n```" ((last logs) "text")) (string/format "%q" logs))
        (check (not (string/find "\r" (string/format "%q" sections))))
        (check (= "Log" (get (last sections) "heading")))))))

(test "status <unit> --json gives the harvest items with kind, text and done, and tolerates others"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "new" "task" "page") :status)))
        (check (= 0 ((run dir "note" "task/page" "harvest" "decision: pick the ordered map") :status)))
        (check (= 0 ((run dir "note" "task/page" "harvest" "backlog: later") :status)))
        (def file (unit-file dir "task/page"))
        (spit file (string/replace "- [ ] backlog: later" "- [x] backlog: later\n  and wrapped\n- [ ] a free-form note\n- [X] process: tidy" (string (slurp file))))
        (def items ((status-json dir "task/page") "harvest"))
        (check (deep= items @[@{"kind" "decision" "text" "pick the ordered map" "done" false}
                              @{"kind" "backlog" "text" "later\nand wrapped" "done" true}
                              @{"kind" "other" "text" "a free-form note" "done" false}
                              @{"kind" "process" "text" "tidy" "done" true}])
               (string/format "%q" items))))))

(test "harvest items ignore comments, tolerate spacing, and end a continuation at an unindented line"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "new" "task" "page") :status)))
        (def file (unit-file dir "task/page"))
        (spit file (string/replace "\n## Log" "<!-- - [ ] backlog: hidden -->\n- [x]  learning: spaced\n  more\nplain line\n  not a continuation\n- [ ]\n\n## Log"
                                   (string (slurp file))))
        (def items ((status-json dir "task/page") "harvest"))
        (check (deep= items @[@{"kind" "learning" "text" "spaced\nmore" "done" true}
                              @{"kind" "other" "text" "" "done" false}])
               (string/format "%q" items))
        # close counts the same open item, even one with no text
        (check (= 0 ((run dir "phase" "task/page" "finalize" "--force") :status)))
        (def c (run dir "close" "task/page"))
        (check (string/find "1 unchecked item(s)" (c :stderr)) (c :stderr))))))

(test "a unit's awaiting flag shows in its status and in the tree, with any value; absent when unset, and created shows"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "new" "task" "held") :status)))
        (check (= 0 ((run dir "new" "task" "free") :status)))
        (check (nil? ((status-json dir "task/held") "awaiting")))
        (add-front (unit-file dir "task/held") "awaiting: owner")
        (check (= "owner" ((status-json dir "task/held") "awaiting")))
        (def by-label (tabseq [u :in ((status-json dir) "units")] (u "label") u))
        (check (= "owner" (get-in by-label ["task/held" "awaiting"])))
        (check (not (has-key? (by-label "task/free") "awaiting")))
        (check (date? ((status-json dir "task/held") "created")))))))

(test "the tree's units carry their sections and harvest only with --detail"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "new" "task" "page" "--purpose" "Show it.") :status)))
        (def plain (get-in (status-json dir) ["units" 0]))
        (check (not (or (has-key? plain "sections") (has-key? plain "harvest"))))
        (def detailed (get-in (status-json dir "--detail") ["units" 0]))
        (check (= "Show it." (text-of (detailed "sections") "Purpose")))
        (check (date? (detailed "created")))
        (check (date? (plain "created")))
        (check (deep= (detailed "harvest") @[]))))))

(test "records in the tree carry their front matter fields and problems, and sections only with --detail"
  (fn []
    (with-repo
      (fn [dir]
        (def id (string/trim ((run dir "record" "backlog" "Wait for BR" "--id") :stdout)))
        (def file (record-file dir "backlog" id))
        (add-front file "needs: owner")
        (add-front file "priority: \"2\"")
        (def records (tabseq [r :in ((status-json dir) "records")] (r "kind") r))
        (def b (records "backlog"))
        (check (and (= "owner" (b "needs")) (= "2" (b "priority")) (date? (b "created"))) (string/format "%q" b))
        (check (deep= (b "problems") @[]))
        (check (not (has-key? b "sections")))
        (def d (records "decision"))
        (check (and (= "accepted" (d "status")) (date? (d "date"))))
        (check (not (has-key? d "needs")))
        (def detailed (tabseq [r :in ((status-json dir "--detail") "records")] (r "kind") r))
        (check (string? (text-of (get-in detailed ["backlog" "sections"]) "Why")))
        (check (string? (text-of (get-in detailed ["decision" "sections"]) "Consequences")))))))

(test "status <record-id> gives one record in full, as JSON or as its fields"
  (fn []
    (with-repo
      (fn [dir]
        (def r (run-with {:in "## Why\nBecause.\n\n## Notes\nSee <!-- hidden --> there."} dir
                         "record" "backlog" "Second" "--body" "-" "--id"))
        (check (= 0 (r :status)) (r :stderr))
        (def id (string/trim (r :stdout)))
        (def j (status-json dir id))
        (check (= id (j "id")))
        (check (= "backlog" (j "kind")))
        (check (= "Because." (text-of (j "sections") "Why")))
        (check (= "See  there." (text-of (j "sections") "Notes")))
        (check (string/find "created: 20" ((run dir "status" id) :stdout)))
        (def human ((run dir "status" id) :stdout))
        (check (= 1 (length (string/find-all id (first (string/split "\n" human))))) human)
        (check (string/find "file: .work/backlog/" human))
        (def unknown (run dir "status" "B-AAAAAAAAAAAAAAAA"))
        (check (not= 0 (unknown :status)))
        (check (string/find "no record \"B-AAAAAAAAAAAAAAAA\"" (unknown :stderr)) (unknown :stderr))))))

(test "status --json lists every backlog record, broken ones too, as many as the human form counts"
  (fn []
    (with-repo
      (fn [dir]
        (each name ["one" "two" "three"] (check (= 0 ((run dir "record" "backlog" name) :status))))
        (spit (string dir "/.work/backlog/B-AAAAAAAAAAAAAAAA-broken.md") "no front matter\n")
        (def listed (filter |(= "backlog" ($ "kind")) ((status-json dir) "records")))
        (check (= 4 (length listed)))
        (check (string/find "backlog: 4 " ((run dir "status") :stdout)))
        (check (some |(not (empty? ($ "problems"))) listed))))))

(test "front matter fields come out by type: scalars as strings, lists as arrays, empty ones left out"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "record" "backlog" "Plain") :status)))
        (def file (record-file dir "backlog" (string/trim ((run dir "record" "backlog" "Typed" "--id") :stdout))))
        (add-front file "needs:")
        (add-front file "refs: one/path#sym")
        (add-front file "supersedes:\n  - D-AAAAAAAAAAAAAAAA\n  - D-BBBBBBBBBBBBBBBB")
        (add-front file "priority: [\"1\", \"2\"]")
        (def r (find |(string/find "Typed" ($ "title")) ((status-json dir) "records")))
        (check (not (has-key? r "needs")) "an empty value is left out")
        (check (deep= (r "refs") @["one/path#sym"]) "a single string is a list of one")
        (check (deep= (r "supersedes") @["D-AAAAAAAAAAAAAAAA" "D-BBBBBBBBBBBBBBBB"]))
        (check (= "1, 2" (r "priority")) "a list in a scalar field is joined")
        (check (not (has-key? (find |(string/find "Plain" ($ "title")) ((status-json dir) "records")) "refs")))))))

# ---------- a work dir from a checkout that is not trusted

(defn symlink [target link]
  (check (= 0 (os/proc-wait (os/spawn ["ln" "-s" target link] :p))) "ln -s failed"))

(defn problems-of [dir]
  (def j (status-json dir))
  (array/concat @[] (j "problems") ;(map |($ "problems") (j "units")) ;(map |($ "problems") (j "records"))))

(defn has-problem [dir text]
  (def all (problems-of dir))
  (check (find |(string/find text $) all) (string "no problem with " text " in " (string/format "%q" all)))
  (def c (run dir "check"))
  (check (not= 0 (c :status)) "check passed")
  (check (string/find text (c :stdout)) (c :stdout)))

(test "a symlinked STATE.md or record is not read, and shows as a problem"
  (fn []
    (with-repo
      (fn [dir]
        (def outside (string (tmp-dir) "/elsewhere.md"))
        (defer (sh/rm (string/slice outside 0 (last (string/find-all "/" outside))))
          (spit outside "---\nphase: execute\n---\n\n# outside\n")
          (def id (new-id dir "task" "linked"))
          (def state (unit-file dir "task/linked"))
          (os/rm state)
          (symlink outside state)
          (def rec (record-file dir "decisions" (first (map |($ "id") ((status-json dir) "records")))))
          (os/rm rec)
          (symlink outside rec)
          (has-problem dir "not read: is a symlink")
          (def j (status-json dir))
          (def u (find |(= ($ "id") id) (j "units")))
          (check (= :null (u "phase")) "the unit's front matter was read through the link")
          (check (find |(= ($ "title") "") (j "records")) "the record's body was read through the link")
          (check (not= 0 ((run dir "phase" id "finalize" "--force") :status)))
          (check (not= 0 ((run dir "note" id "log" "more") :status)))
          (check (= "---\nphase: execute\n---\n\n# outside\n" (string (slurp outside))) "written through the link"))))))

(test "a symlink where a unit, type, or record directory belongs is not followed"
  (fn []
    (with-repo
      (fn [dir]
        (def outside (tmp-dir))
        (defer (sh/rm outside)
          (new-id dir "task" "real")
          (os/mkdir (string outside "/U-AAAAAAAAAAAAAAAA-evil"))
          (spit (string outside "/U-AAAAAAAAAAAAAAAA-evil/STATE.md") "---\nphase: execute\n---\n\n# evil\n")
          (symlink (string outside "/U-AAAAAAAAAAAAAAAA-evil") (string dir "/.work/task/U-AAAAAAAAAAAAAAAA-evil"))
          (symlink outside (string dir "/.work/slice"))
          (sh/rm (string dir "/.work/learnings"))
          (symlink outside (string dir "/.work/learnings"))
          (has-problem dir "task/U-AAAAAAAAAAAAAAAA-evil: is a symlink, not followed")
          (has-problem dir "slice: is a symlink, not followed")
          (has-problem dir "learnings: is a symlink, not followed")
          (def j (status-json dir))
          (check (= 1 (length (j "units"))) "only the real unit loads")
          (check (not (find |(= ($ "kind") "learning") (j "records"))))
          (check (string/find "slice: is a symlink" ((run dir "status") :stdout))))))))

(test "a document over the size cap is not read, one under it is"
  (fn []
    (with-repo
      (fn [dir]
        (new-id dir "task" "big")
        (new-id dir "task" "fine")
        (def pad (fn [n] (string/repeat "x" n)))
        (def cap 1048576)
        (defn grow [lbl bytes]
          (def f (unit-file dir lbl))
          (spit f (string (slurp f) "\n" (pad (- bytes (length (slurp f)) 1)))))
        (grow "task/big" (+ cap 1))
        (grow "task/fine" cap)
        (has-problem dir "not read: larger than 1 MiB")
        (def units (get (status-json dir) "units"))
        (check (= 1 (length (filter |(not (empty? ($ "problems"))) units))) "only the big one")
        (check (find |(and (= ($ "label") "task/fine") (= ($ "phase") "initialize")) units))))))

(test "a fifo in a document's place is refused without being opened"
  (fn []
    (with-repo
      (fn [dir]
        (new-id dir "task" "piped")
        (def state (unit-file dir "task/piped"))
        (os/rm state)
        (check (= 0 (os/proc-wait (os/spawn ["mkfifo" state] :p))) "mkfifo failed")
        (has-problem dir "not read: is a fifo, not a file")))))

(defn repo-with-linked-work [f]
  (def outside (tmp-dir))
  (def repo (tmp-dir))
  (defer (do (sh/rm outside) (sh/rm repo))
    (check (= 0 ((run outside "init") :status)))
    (check (= 0 (os/proc-wait (os/spawn ["git" "-C" repo "init" "-q"] :p))))
    (symlink (string outside "/.work") (string repo "/.work"))
    (f repo (string outside "/.work"))))

(defn refused [repo want]
  (def r (run repo "status"))
  (check (not= 0 (r :status)))
  (check (string/find want (r :stderr)) (r :stderr))
  (def c (run repo "check"))
  (check (not= 0 (c :status)))
  (check (string/find want (c :stdout)) (c :stdout)))

(test "a work dir found by searching that is a symlink out of the repo is refused"
  (fn []
    (repo-with-linked-work
      (fn [repo outside-work]
        (refused repo "work dir is a symlink")))))

(test "a work dir the operator names may be outside the repo"
  (fn []
    (repo-with-linked-work
      (fn [repo outside-work]
        (ok (run repo "status" "--root" outside-work))
        (ok (run-with {:env {"DEV_PROC_ROOT" outside-work}} repo "status"))
        (git-in repo "config" "dev-proc.root" outside-work)
        (ok (run repo "status"))))))

(test "a work dir that is a symlink is refused even inside the repo, or when dangling"
  (fn []
    (with-repo
      (fn [dir]
        (os/rename (string dir "/.work") (string dir "/store"))
        (symlink "store" (string dir "/.work"))
        (refused dir "work dir is a symlink")
        (os/rm (string dir "/.work"))
        (symlink "nowhere" (string dir "/.work"))
        (refused dir "work dir is a symlink")))))

(test "a repo whose only root is refused is reported, not taken for having no work dir"
  (fn []
    (with-repo
      (fn [dir]
        (os/rename (string dir "/.work") (string dir "/store"))
        (symlink "store" (string dir "/.work"))
        (def s (run dir "status"))
        (check (= 2 (s :status)) (string "a single-root command fails with 2, got " (s :status)))
        (check (string/find "work dir is a symlink" (s :stderr)) (s :stderr))
        (def c (run dir "check"))
        (check (= 1 (c :status)) (string "check exits 1, got " (c :status) ": " (c :stderr)))
        (check (string/find "work dir is a symlink" (c :stdout)) (c :stdout))
        (def f (run dir "find" "anything"))
        (check (not= 3 (f :status)) "find does not call it no work dir")
        (check (string/find "work dir is a symlink" (f :stderr)) (f :stderr))))))

(test "a committed link to a git-ignored root or to the git dir is not a team root"
  (fn []
    (with-repo
      (fn [dir]
        (os/mkdir (string dir "/sub"))
        (spit (string dir "/.git/info/exclude") ".mine\n")
        (ok (run dir "init" "--root" (string dir "/.mine")))
        (new-id dir "task" "private" "--root" (string dir "/.mine"))
        (symlink "../.mine" (string dir "/sub/.work"))
        (def r (run (string dir "/sub") "status"))
        (check (not= 0 (r :status)))
        (check (string/find "work dir is a symlink" (r :stderr)) (r :stderr))
        (def c (run dir "check"))
        (check (string/find "sub/.work: work dir is a symlink" (c :stdout)) (c :stdout))
        (check (not (string/find "private" (c :stdout))) "a private unit showed")
        (os/rm (string dir "/sub/.work"))
        (symlink "../.git" (string dir "/sub/.work"))
        (check (not= 0 ((run (string dir "/sub") "status") :status)))
        (check (string/find "sub/.work: work dir is a symlink" ((run dir "check") :stdout)))))))

(test "a ignored plain work dir is still a work dir, and a .dev-proc.toml cannot name .git"
  (fn []
    (with-repo
      (fn [dir]
        (os/mkdir (string dir "/sub"))
        (spit (string dir "/.git/info/exclude") "sub/.work\n")
        (ok (run (string dir "/sub") "init"))
        (check (string/find "(out-of-band)" ((ok (run (string dir "/sub") "status")) :stdout)))
        (spit (string dir "/.dev-proc.toml") "work_dir = \".git\"\n")
        (check (string/find "work_dir cannot be .git" ((run dir "status") :stderr)))))))

(test "a linked .dev-proc.toml, dangling or not, is refused and a sweep goes on past it"
  (fn []
    (with-repo
      (fn [dir]
        (def other (tmp-dir))
        (defer (sh/rm other)
          (spit (string other "/c.toml") "work_dir = \".x\"\n")
          (os/mkdir (string dir "/sub"))
          (new-id dir "task" "fine")
          (each target [(string other "/c.toml") "missing.toml"]
            (symlink target (string dir "/sub/.dev-proc.toml"))
            (def r (run (string dir "/sub") "status"))
            (check (not= 0 (r :status)))
            (check (string/find ".dev-proc.toml: not read: is a symlink" (r :stderr)) (r :stderr))
            (def c (run dir "check"))
            (check (not= 0 (c :status)))
            (check (string/find "sub/.dev-proc.toml: not read: is a symlink" (c :stdout)) (c :stdout))
            (os/rm (string dir "/sub/.dev-proc.toml"))))))))

(defn big-file [path bytes] (spit path (string "---\nstatus: accepted\n---\n\n# big\n" (string/repeat "x" bytes))))

(test "a ref is looked up only in a regular, small file inside the repo"
  (fn []
    (with-repo
      (fn [dir]
        (def outside (tmp-dir))
        (defer (sh/rm outside)
          (spit (string dir "/real.rs") "fn foo() {}\n")
          (spit (string outside "/o.rs") "fn foo() {}\n")
          (symlink "real.rs" (string dir "/inside.rs"))
          (symlink (string outside "/o.rs") (string dir "/outside.rs"))
          (symlink "/dev/zero" (string dir "/zero.rs"))
          (big-file (string dir "/huge.rs") 1048576)
          (check (= 0 (os/proc-wait (os/spawn ["mkfifo" (string dir "/pipe.rs")] :p))))
          (def rec (record-file dir "decisions" (first (map |($ "id") ((status-json dir) "records")))))
          (defn set-refs [& refs]
            (spit rec (string "---\nstatus: accepted\ndate: 2026-11-10\nread_if:\n  - x\nrefs:\n"
                              (string/join (map |(string "  - " $) refs) "\n") "\n---\n\n# A decision\n")))
          (spit (string dir "/.git/info/exclude") "built.rs\n")
          (spit (string dir "/built.rs") "fn foo() {}\n")
          (set-refs "inside.rs#foo" "real.rs#foo")
          (check (= 0 ((run dir "check") :status)) "links inside the repo are fine")
          (each [ref want] [["outside.rs#foo" "lies outside the repo"]
                            ["zero.rs#foo" "lies outside the repo"]
                            ["pipe.rs#foo" "is a fifo, not a file"]
                            [".git/config#core" "is git-ignored or in the git dir"]
                            ["built.rs#foo" "is git-ignored or in the git dir"]
                            ["huge.rs#foo" "too large to check the symbol"]]
            (set-refs "real.rs#foo" ref)
            (def c (run dir "check"))
            (check (not= 0 (c :status)) ref)
            (check (string/find want (c :stdout)) (c :stdout))))))))

(test "new, record and rescope write nothing through a linked directory"
  (fn []
    (with-repo
      (fn [dir]
        (def outside (tmp-dir))
        (defer (sh/rm outside)
          (def task (new-id dir "task" "mover"))
          (symlink outside (string dir "/.work/slice"))
          (sh/rm (string dir "/.work/backlog"))
          (symlink outside (string dir "/.work/backlog"))
          (each cmd [["new" "slice" "x" "--owner" "BR"]
                     ["record" "backlog" "Idea"]
                     ["rescope" task "--type" "slice"]]
            (def r (run dir ;cmd))
            (check (not= 0 (r :status)) (string/join cmd " "))
            (check (string/find "is a symlink" (r :stderr)) (r :stderr))
            (check (empty? (os/dir outside)) (string "written through for " (string/join cmd " "))))
          (check (os/stat (string dir "/.work/task/" (first (os/dir (string dir "/.work/task"))) "/STATE.md"))
                 "the unit was moved away"))))))

(test "a unit whose STATE.md was refused is not changed half way"
  (fn []
    (with-repo
      (fn [dir]
        (def id (new-id dir "task" "stuck"))
        (def state (unit-file dir "task/stuck"))
        (os/rm state)
        (symlink "nowhere" state)
        (each cmd [["rescope" id "--name" "moved"] ["note" id "log" "more"] ["phase" id "execute" "--force"]]
          (def r (run dir ;cmd))
          (check (not= 0 (r :status)))
          (check (string/find "cannot be changed: not read: is a symlink" (r :stderr)) (r :stderr)))
        (check (string/find "-stuck" (first (os/dir (string dir "/.work/task")))) "the folder was renamed")))))

(test "an unreadable file or folder is a problem, not a crash or a missing STATE.md"
  (fn []
    # root can read anything, so there is nothing to refuse
    (when (= "0" (string/trim (sh/exec-slurp "id" "-u"))) (break))
    (with-repo
      (fn [dir]
        (new-id dir "task" "locked")
        (new-id dir "task" "shut")
        (def locked (os/dir (string dir "/.work/task")))
        (def [a b] (let [names (sort locked)] [(string dir "/.work/task/" (names 0)) (string dir "/.work/task/" (names 1))]))
        (defer (do (os/chmod (string a "/STATE.md") 8r644) (os/chmod b 8r755))
          (os/chmod (string a "/STATE.md") 0)
          (os/chmod b 8r644)
          (def c (run dir "check"))
          (check (string/find "not read: cannot be opened" (c :stdout)) (c :stdout))
          (check (string/find "not read: cannot be read" (c :stdout)) (c :stdout))
          (check (not (string/find "missing STATE.md" (c :stdout))) (c :stdout)))))))

(test "an oversize record is a problem on that record"
  (fn []
    (with-repo
      (fn [dir]
        (big-file (string dir "/.work/decisions/D-AAAAAAAAAAAAAAAA-big.md") 1048576)
        (def c (run dir "check"))
        (check (string/find "D-AAAAAAAAAAAAAAAA-big.md: not read: larger than 1 MiB" (c :stdout)) (c :stdout))))))

(test "the documents one command reads may use only so many bytes between them"
  (fn []
    (with-repo
      (fn [dir]
        (for i 0 66
          (big-file (string dir "/.work/decisions/D-AAAAAAAAAAAAA" (string/format "%c%c%c" (+ 65 (div i 26)) (+ 65 (% i 26)) 65) "-b.md")
                    1048000))
        (def c (run dir "check"))
        (check (string/find "past the 64 MiB one command may read" (c :stdout)) (c :stdout))))))

(test "dig does not follow a link inside closed/"
  (fn []
    (with-repo
      (fn [dir]
        (def mine (tmp-dir))
        (defer (sh/rm mine)
          (def root (string mine "/w"))
          (git-in dir "config" "dev-proc.root" root)
          (ok (run dir "init"))
          (def [task _] (close-and-supersede dir))
          (ok (run dir "close" task))
          (symlink ".." (string root "/closed/loop"))
          (check (string/find "# task/private" ((ok (run dir "dig" task)) :stdout))))))))

(test "new --from keeps the backlog item when the folder cannot be made"
  (fn []
    (with-repo
      (fn [dir]
        (def outside (tmp-dir))
        (defer (sh/rm outside)
          (def item (string/trim ((ok (run dir "record" "backlog" "Idea" "--id")) :stdout)))
          (symlink outside (string dir "/.work/wave"))
          (def r (run dir "new" "wave" "w" "--from" item "--owner" "BR"))
          (check (not= 0 (r :status)))
          (check (string/find ".work/wave: is a symlink" (r :stderr)) (r :stderr))
          (check (os/stat (record-file dir "backlog" item)) "the item was deleted")
          (check (empty? (os/dir outside))))))))

(test "record --supersedes writes nothing when closed/ is a link"
  (fn []
    (with-repo
      (fn [dir]
        (def mine (tmp-dir))
        (def outside (tmp-dir))
        (defer (do (sh/rm mine) (sh/rm outside))
          (def root (string mine "/w"))
          (git-in dir "config" "dev-proc.root" root)
          (ok (run dir "init"))
          (def old (string/trim ((ok (run dir "record" "decision" "Old call" "--read-if" "x" "--id")) :stdout)))
          (symlink outside (string root "/closed"))
          (def r (run dir "record" "decision" "New call" "--read-if" "x" "--supersedes" old))
          (check (not= 0 (r :status)))
          (check (= 1 (length (os/dir (string root "/decisions")))) "a record was written or lost")
          (check (empty? (os/dir outside))))))))

(test "the byte budget is one per command, not one per root"
  (fn []
    (with-repo
      (fn [dir]
        (os/mkdir (string dir "/sub"))
        (ok (run (string dir "/sub") "init"))
        (os/mkdir (string dir "/sub/.work/decisions"))
        (each work [".work" "sub/.work"]
          (for i 0 34
            (big-file (string dir "/" work "/decisions/D-AAAAAAAAAAAAAAA" (string/format "%c" (+ 65 i)) "-b.md") 1048000)))
        (def c (run dir "check"))
        (check (string/find "past the 64 MiB one command may read" (c :stdout)) (c :stdout))))))

(test "a command that needs a work dir exits 3 with nothing on stdout where there is none, in a repo or not"
  (fn []
    (def bare (tmp-dir))
    (def repo (tmp-dir))
    (defer (do (sh/rm bare) (sh/rm repo))
      (check (= 0 (os/proc-wait (os/spawn ["git" "-C" repo "init" "-q"] :p))) "git init failed")
      (each [where dir] [["outside a repo" bare] ["in a repo" repo]]
        (each args [["status"] ["status" "--json"] ["status" "--json" "--detail"] ["note" "U-X" "now" "t"]
                    ["new" "task" "t"] ["phase" "U-X" "execute"] ["record" "backlog" "t"] ["dig" "U-X"]
                    ["check"] ["find" "anything"] ["find" "anything" "--json"]]
          (def r (run dir ;args))
          (def what (string where ": " (string/join args " ")))
          (check (= 3 (r :status)) (string what " exited " (r :status)))
          (check (= "" (r :stdout)) (string what " printed on stdout"))
          (check (string/find "no work dir" (r :stderr)) (string what ": " (r :stderr))))))))

(test "a reference that names nothing active exits 4, with nothing on stdout; a malformed or ambiguous one exits 2"
  (fn []
    (with-repo
      (fn [dir]
        (def unit "U-AAAAAAAAAAAAAAAA")
        (def gone "D-AAAAAAAAAAAAAAAA")
        (def real (new-id dir "task" "real" "--execute"))
        (defn exits [code what & args]
          (def r (run dir ;args))
          (check (= code (r :status)) (string what ": exited " (r :status) ", wanted " code ": " (r :stderr)))
          (check (= "" (r :stdout)) (string what ": printed on stdout")))
        (each [what args]
              [["status by id" ["status" unit]] ["status by label" ["status" "task/none"]]
               ["status of a record" ["status" gone]] ["status --json" ["status" unit "--json"]]
               ["note" ["note" unit "now" "x"]] ["note by label" ["note" "task/none" "now" "x"]]
               ["phase" ["phase" unit "execute"]] ["rescope" ["rescope" unit "--name" "x"]]
               ["rescope --parent" ["rescope" real "--parent" unit]]
               ["close" ["close" unit]] ["close --decision" ["close" real "--scrap" "--decision" gone]]
               ["new --parent" ["new" "task" "child" "--parent" unit]]
               ["new --from" ["new" "task" "child" "--from" "B-AAAAAAAAAAAAAAAA"]]
               ["record --supersedes" ["record" "decision" "Newer" "--supersedes" gone]]]
          (exits 4 what ;args))
        (each [what args]
              [["status, malformed id" ["status" "U-short"]] ["status, a bare word" ["status" "nothing"]]
               ["note, malformed id" ["note" "U-short" "now" "x"]]
               ["status, a path" ["status" "foo/bar"]] ["status, ./x/y" ["status" "./x/y"]]
               ["status, a bad label" ["status" "task/Bad Name"]]
               ["new --parent, malformed" ["new" "task" "child" "--parent" "U-short"]]
               ["record --supersedes, malformed" ["record" "decision" "Newer" "--supersedes" "D-short"]]]
          (exits 2 what ;args))
        # Two units with one label, as a merge of two branches can leave.
        (check (= 0 (os/execute ["cp" "-r" (string dir "/.work/task/" real "-real") (string dir "/.work/task/U-BBBBBBBBBBBBBBBB-real")] :p)))
        (exits 2 "ambiguous label" "status" "task/real")))))

(test "a recorded parent that is no longer active is a failure, exit 2, not a name the user gave"
  (fn []
    (with-repo
      (fn [dir]
        (def parent (new-id dir "slice" "par" "--execute"))
        (def child (new-id dir "task" "kid" "--parent" parent "--execute"))
        (sh/rm (string dir "/.work/slice/" parent "-par"))
        (def r (run dir "rescope" child "--name" "kid2"))
        (check (= 2 (r :status)) (string "exited " (r :status) ": " (r :stderr)))
        (check (string/find "recorded parent" (r :stderr)) (r :stderr))
        (check (= "" (r :stdout)))
        (check (= 0 ((run dir "rescope" child "--name" "kid2" "--parent" "none") :status)) "--parent none still works")))))

(test "close --scrap --decision names a record that is not a decision: exit 2 with the kind said"
  (fn []
    (with-repo
      (fn [dir]
        (def u (new-id dir "task" "scrapped" "--execute"))
        (def learning (string/trim ((run dir "record" "learning" "A lesson" "--read-if" "x" "--id") :stdout)))
        (def r (run dir "close" u "--scrap" "--decision" learning))
        (check (= 2 (r :status)) (string "exited " (r :status) ": " (r :stderr)))
        (check (string/find (string learning " is not a decision") (r :stderr)) (r :stderr))))))

(test "failures other than a missing work dir keep their exit codes"
  (fn []
    (with-repo
      (fn [dir]
        (check (= 0 ((run dir "record" "decision" "Dangling" "--read-if" "x" "--ref" "no/such/path#sym") :status)) "recording the dangling ref")
        (check (= 1 ((run dir "check") :status)) "check finding errors")
        (check (= 2 ((run dir "frobnicate") :status)) "unknown command")
        (check (= 2 ((run dir "note" "x") :status)) "bad arguments")
        (check (= 2 ((run dir "--root" (string dir "/missing") "status") :status)) "--root that does not exist")))))

(test ".dev-proc.toml naming a missing work_dir is no work dir, exit 3"
  (fn []
    (def repo (tmp-dir))
    (defer (sh/rm repo)
      (check (= 0 (os/proc-wait (os/spawn ["git" "-C" repo "init" "-q"] :p))) "git init failed")
      (spit (string repo "/.dev-proc.toml") "work_dir = \".tasks\"\n")
      (def r (run repo "status"))
      (check (= 3 (r :status)) (string "exited " (r :status) ": " (r :stderr)))
      (check (= "" (r :stdout)) "printed on stdout"))))

(test "a named root that does not exist is a failure, exit 2, not no work dir"
  (fn []
    (def repo (tmp-dir))
    (defer (sh/rm repo)
      (check (= 0 (os/proc-wait (os/spawn ["git" "-C" repo "init" "-q"] :p))) "git init failed")
      (def missing (string repo "/missing-root"))
      (def env (run-with {:env {"DEV_PROC_ROOT" missing}} repo "status"))
      (check (= 2 (env :status)) (string "DEV_PROC_ROOT exited " (env :status) ": " (env :stderr)))
      (git-in repo "config" "dev-proc.root" missing)
      (each args [["status"] ["check"] ["find" "anything"]]
        (def cfg (run repo ;args))
        (check (= 2 (cfg :status)) (string "dev-proc.root, " (string/join args " ") " exited " (cfg :status) ": " (cfg :stderr)))))))

(test "a repo whose only root is an out-of-band dev-proc.root has a work dir: check passes, the hook is silent"
  (fn []
    (def repo (tmp-dir))
    (def mine (tmp-dir))
    (defer (do (sh/rm repo) (sh/rm mine))
      (check (= 0 (os/proc-wait (os/spawn ["git" "-C" repo "init" "-q"] :p))) "git init failed")
      (git-in repo "config" "dev-proc.root" (string mine "/my-work"))
      (ok (run repo "init"))
      (def c (run repo "check"))
      (check (= 0 (c :status)) (c :stderr))
      (check (string/find "ok (1 root)" (c :stdout)) (c :stdout))
      (def h (run-with {:env {"DEV_PROC_STRICT" "1"}} repo "check" "--staged" "--hook"))
      (check (= 0 (h :status)) (h :stderr))
      (check (= "" (string (h :stdout) (h :stderr))) (string "hook printed: " (h :stdout) (h :stderr))))))

(test "the commit hooks stay silent and exit 0 in a repo with no work dir, strict or not"
  (fn []
    (def repo (tmp-dir))
    (defer (sh/rm repo)
      (check (= 0 (os/proc-wait (os/spawn ["git" "-C" repo "init" "-q"] :p))) "git init failed")
      (def msg (string repo "/msg"))
      (spit msg "a commit\n")
      (each strict [nil "1"]
        (def env (if strict {"DEV_PROC_STRICT" strict} {}))
        (each args [["check" "--staged" "--hook"] ["check-msg" msg]]
          (def r (run-with {:env env} repo ;args))
          (def what (string (string/join args " ") (if strict " (strict)" "")))
          (check (= 0 (r :status)) (string what " exited " (r :status) ": " (r :stderr)))
          (check (= "" (string (r :stdout) (r :stderr))) (string what " printed: " (r :stdout) (r :stderr))))))))

(when (> failures 0)
  (eprint failures " test(s) failed")
  (os/exit 1))
(print "dev-proc: all tests passed")
