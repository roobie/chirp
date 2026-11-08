# Every janet example in the tasks help topic runs as it is, offline: the
# topic promises examples that work when pasted into a script.
(import spork/sh)

# The child resolves a relative program path after :cd, so it has to be absolute.
(def- exe
  (let [e (dyn *executable*)
        [ok p] (protect (os/realpath e))]
    (if ok p (string (os/cwd) "/" e))))

(defn- run [dir & args]
  (def p (os/spawn [exe ;args] :p {:cd dir :out :pipe :err :pipe}))
  (def [out err]
    (try (ev/with-deadline 60 (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
      ([_] (os/proc-kill p true) [nil "killed after 60s"])))
  [(os/proc-wait p) (string out) (string err)])

(defn- examples
  "[section code] for each ```janet fence in markdown text."
  [text]
  (def out @[])
  (var section nil)
  (var code nil)
  (each line (string/split "\n" (string/replace-all "\r" "" text))
    (cond
      code (if (string/has-prefix? "```" line)
             (do (array/push out [section (string/join code "\n")]) (set code nil))
             (array/push code line))
      (string/has-prefix? "## " line) (set section (string/slice line 3))
      (= "```janet" (string/trim line)) (set code @[])))
  out)

(defn main [&]
  (def [code text err] (run (os/cwd) "--help" "read" "tasks"))
  (assert (= 0 code) (string "help read tasks: " err))
  (def all (examples text))
  (assert (< 10 (length all)) (string "only " (length all) " examples found"))
  (def tmp (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                   "/chirp-smoke-tasks-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (defer (sh/rm tmp)
    (eachp [i [section src]] all
      (def dir (string tmp "/" i))
      (sh/create-dirs dir)
      (spit (string dir "/example.janet") src)
      # The working directory is the example's own, so files it writes stay there.
      (def [c out err] (run dir (string dir "/example.janet")))
      (assert (= 0 c) (string "tasks example in \"" section "\" exits " c ":\n" src "\n" out err))))
  (print "ok tasks (" (length all) " examples)"))
