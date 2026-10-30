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
    (def [o e] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
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

(test "note rejects an unknown section and empty text"
  (fn []
    (note-test
      (fn [dir _]
        (check (string/find "usage: note" ((run dir "note" "task/noted" "purpose" "x") :stderr)))
        (check (string/find "needs text" ((run dir "note" "task/noted" "now") :stderr)))
        (check (string/find "no active unit" ((run dir "note" "task/none" "now" "x") :stderr)))))))

(when (> failures 0)
  (eprint failures " test(s) failed")
  (os/exit 1))
(print "dev-proc: all tests passed")
