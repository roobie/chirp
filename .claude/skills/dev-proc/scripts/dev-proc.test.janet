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
(defn run [cwd & args]
  (def old (os/cwd))
  (os/cd cwd)
  (defer (os/cd old)
    (def p (os/spawn [(dyn :executable) cli ;args] :p {:out :pipe :err :pipe}))
    (def [o e] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
    {:status (os/proc-wait p) :stdout (string (or o "")) :stderr (string (or e ""))}))

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

(when (> failures 0)
  (eprint failures " test(s) failed")
  (os/exit 1))
(print "dev-proc: all tests passed")
