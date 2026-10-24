# Smoke driver: runs the checks with the very binary that runs this script, so
# the same code path works on every OS (Windows runners have no usable sh).
# Usage: chirp test/smoke/run.janet
(def- checks ["zip" "sqlite" "toml" "https-get" "https-server" "help" "changelog" "cli-help" "stdin" "self-update"])
# A check that hangs (as https-server did on windows) fails on its own line in
# seconds, instead of the CI job timing out with no hint of which check hung.
(def- timeout-seconds 60)

(defn- dir-of [file]
  (def cut (max -1 ;(string/find-all "/" file) ;(string/find-all "\\" file)))
  (string/slice file 0 (+ cut 1)))

(defn- run
  "Spawn the binary with args. Returns [exit-code stdout stderr]; a run that
  outlives the timeout is killed and returns a nil exit code."
  [& args]
  (def p (os/spawn [(dyn *executable*) ;args] :p {:out :pipe :err :pipe}))
  (try
    (ev/with-deadline timeout-seconds
      (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
      [(os/proc-wait p) (string out) (string err)])
    ([_]
      (os/proc-kill p true)
      [nil "" (string/format "killed after %ds" timeout-seconds)])))

(var failed 0)

(defn- report [name ok detail]
  (unless ok (++ failed))
  (printf "%s %s%s" (if ok "ok  " "FAIL") name
          (if (and detail (not (empty? detail))) (string " - " (string/trim detail)) "")))

(defn main [&]
  # An unofficial build must say so in its identity line.
  (def [code out err] (run "-v"))
  (report "version" (and (= 0 code)
                         (string/has-prefix? "chirp " out)
                         (string/find "unofficial build" out))
          (string out err))

  # The https-server check makes its server log the rejected untrusted client
  # on stderr, so stderr is shown only when a check fails.
  (def here (dir-of (dyn *current-file*)))
  (each name checks
    (def [code out err] (run (string here name ".janet")))
    (def ok (= 0 code))
    (report name ok (if ok out (string out err))))

  (when (pos? failed)
    (eprintf "smoke: %d check(s) failed" failed)
    (os/exit 1))
  (print "smoke: all checks passed"))
