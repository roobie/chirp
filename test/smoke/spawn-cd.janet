# os/execute and os/spawn run the child in the directory named by :cd, and
# leave the parent's directory alone (#5).
(import spork/sh)

(defn- tmpdir [tag]
  (def d (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                 "/chirp-smoke-" tag "-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs d)
  (os/realpath d))

# The child resolves a relative program path after it changes directory; a bare
# name found on PATH has no file here and stays as it is.
(def exe (let [e (dyn *executable*) [ok p] (protect (os/realpath e))] (if ok p e)))

(defn- cwd-of
  "Spawn the binary with flags and env, have it print its cwd, return that."
  [flags env]
  (def p (os/spawn [exe "-e" "(prin (os/cwd))"] flags (merge env {:out :pipe})))
  (def out (ev/read (p :out) :all))
  (assert (= 0 (os/proc-wait p)) "child failed")
  (os/realpath (string out)))

(defn main [&]
  (def tmp (tmpdir "spawn-cd"))
  (defer (sh/rm tmp)
    (def before (os/cwd))

    (def got (cwd-of :p {:cd tmp}))
    (assert (= tmp got) (string "os/spawn :cd ran in " got ", not " tmp))

    # With :e the table is the whole environment, :cd included.
    (def got-e (cwd-of :pe (merge (os/environ) {:cd tmp})))
    (assert (= tmp got-e) (string "os/spawn :e :cd ran in " got-e ", not " tmp))

    # os/execute has no :pipe, so the child leaves a file where it ran.
    (def code (os/execute [exe "-e" "(spit \"marker\" \"x\")"] :p {:cd tmp}))
    (assert (= 0 code) (string "os/execute :cd exit " code))
    (assert (os/stat (string tmp "/marker")) "os/execute :cd did not run in the directory")

    (assert (= before (os/cwd)) "the parent's cwd changed")

    # A missing directory fails instead of running the child elsewhere.
    (def missing (string tmp "/no-such-dir"))
    (def [ok res] (protect (os/execute [exe "-e" "(spit \"stray\" \"x\")"] :p {:cd missing})))
    (assert (and (not (and ok (= 0 res))) (not (os/stat (string before "/stray"))))
            (string "a missing :cd directory ran the child: " (string/format "%q" res))))
  (print "ok spawn-cd"))
