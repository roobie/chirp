# Run every test in the repo: each file named *.test.janet, wherever it lives,
# so a new test needs no list. They run side by side, each as its own process
# of the chirp that runs this, from the repo root.
# Usage: chirp tools/test.janet [<path prefix>...]
#   chirp tools/test.janet            every test
#   chirp tools/test.janet src tools  only the tests under src/ and tools/
# None of them needs a build: they test Janet source from the checkout.

(def- timeout-seconds 180)

(defn- capture [& cmd]
  (def p (os/spawn cmd :p {:out :pipe :err :pipe}))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  (def code (os/proc-wait p))
  (unless (zero? code) (error (string (first cmd) " failed: " (string/trim (string (or err ""))))))
  (string (or out "")))

(defn- run-test
  "Run one test file. Returns {:file :ok :seconds :output}."
  [exe file]
  (def start (os/clock :monotonic))
  (def p (os/spawn [exe file] :p {:out :pipe :err :pipe}))
  (def [code output]
    (try
      (ev/with-deadline timeout-seconds
        (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
        [(os/proc-wait p) (string (or out "") (or err ""))])
      ([_]
        (os/proc-kill p true)
        [nil (string/format "killed after %ds" timeout-seconds)])))
  {:file file :ok (= 0 code) :seconds (- (os/clock :monotonic) start) :output output})

(defn main [_ & prefixes]
  (os/cd (string/trim (capture "git" "rev-parse" "--show-toplevel")))
  # Tracked files and new ones not yet added, never ignored ones (build trees).
  (def files
    (sorted (filter |(and (not (empty? $))
                          (or (empty? prefixes) (some (fn [p] (string/has-prefix? p $)) prefixes)))
                    (string/split "\n" (capture "git" "ls-files" "-co" "--exclude-standard"
                                                "--" "*.test.janet")))))
  (when (empty? files)
    (eprint "test: no *.test.janet under " (string/join prefixes ", "))
    (os/exit 2))
  (def start (os/clock :monotonic))
  (def exe (dyn *executable*))
  (def done (ev/chan))
  (each f files (ev/spawn (ev/give done (run-test exe f))))
  (def results (sort-by |($ :file) (seq [_ :in files] (ev/take done))))
  (var failed 0)
  (each {:file file :ok ok :seconds seconds :output output} results
    (printf "%s %s (%.1fs)" (if ok "ok  " "FAIL") file seconds)
    (unless ok
      (++ failed)
      (each line (string/split "\n" (string/trim output)) (print "     " line))))
  (def total (- (os/clock :monotonic) start))
  (when (pos? failed)
    (flush)
    (eprintf "test: %d of %d failed (%.1fs)" failed (length files) total)
    (os/exit 1))
  (printf "test: all %d passed (%.1fs)" (length files) total))
