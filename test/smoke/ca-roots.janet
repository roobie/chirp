# Which trust store chirp uses. macOS and windows export the OS store's roots
# to a file, which https-get then proves against a real host; elsewhere the
# system bundle file is used. Also times a bare start, with and without the export.
(def exe (let [e (dyn *executable*) [ok p] (protect (os/realpath e))] (if ok p e)))

(defn- ca-of
  "The ca part of the child's -v line, run with env as its whole environment."
  [env]
  (def p (os/spawn [exe "-v"] :pe (merge env {:out :pipe})))
  (def out (string (ev/read (p :out) :all)))
  (assert (= 0 (os/proc-wait p)) "chirp -v failed")
  (def at (string/find " - ca: " out))
  (assert at (string "no ca in: " out))
  (string/trim (string/slice out (+ at 7))))

(defn main [&]
  (def env (tabseq [[k v] :pairs (os/environ) :unless (= "SSL_CERT_FILE" k)] k v))
  (def t0 (os/clock :monotonic))
  (def ca (ca-of env))
  (def ms (math/round (* 1000 (- (os/clock :monotonic) t0))))
  (def store (case (os/which) :macos "keychain" :windows "windows store" :mingw "windows store"))
  (when store
    (def prefix (string store " ("))
    (assert (string/has-prefix? prefix ca) (string "expected the " store ", got " ca))
    (def path (string/slice ca (length prefix) -2))
    (def pem (string (slurp path)))
    (def n (length (string/find-all "-----BEGIN CERTIFICATE-----" pem)))
    (assert (> n 20) (string path " holds only " n " certificates"))
    # A chirp started by this one inherits SSL_CERT_FILE and must name it the same.
    # It skips the export, so the difference in time is what the export costs.
    (def t1 (os/clock :monotonic))
    (def inherited (ca-of (merge env {"SSL_CERT_FILE" path})))
    (def ms-inherited (math/round (* 1000 (- (os/clock :monotonic) t1))))
    (assert (= ca inherited) (string "inherited: " inherited))
    (print "ok ca-roots " n " roots from the " ca ", chirp -v in " ms " ms, "
           ms-inherited " ms without the export"))
  (unless store
    (assert (not (string/has-prefix? "none found" ca)) (string "no CA bundle: " ca))
    (print "ok ca-roots " ca ", chirp -v in " ms " ms")))
