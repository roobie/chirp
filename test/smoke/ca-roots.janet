# Which trust store chirp uses. macOS and windows export the OS store's roots
# to a file, which https-get then proves against a real host; elsewhere the
# system bundle file is used. The export happens only once TLS is needed, so a
# start without TLS must not pay for it.
(def exe (let [e (dyn *executable*) [ok p] (protect (os/realpath e))] (if ok p e)))

(defn- ca-of
  "The ca part of the child's -v identity line, run with env as its whole environment."
  [env]
  (def p (os/spawn [exe "-v"] :pe (merge env {:out :pipe})))
  # The identity line is the first; the project site follows it.
  (def out (first (string/split "\n" (string (ev/read (p :out) :all)))))
  (assert (= 0 (os/proc-wait p)) "chirp -v failed")
  (def at (string/find " - ca: " out))
  (assert at (string "no ca in: " out))
  (string/trim (string/slice out (+ at 7))))

(defn- run-e
  "What chirp -e code prints, run with env as its whole environment, and how
  many milliseconds it took."
  [env code]
  (def t (os/clock :monotonic))
  (def p (os/spawn [exe "-e" code] :pe (merge env {:out :pipe})))
  (def out (string/trim (string (ev/read (p :out) :all))))
  (assert (= 0 (os/proc-wait p)) (string "chirp -e failed: " code))
  [out (math/round (* 1000 (- (os/clock :monotonic) t)))])

(def- show-env `(print (or (os/getenv "SSL_CERT_FILE") "unset"))`)

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
    (def inherited (ca-of (merge env {"SSL_CERT_FILE" path})))
    (assert (= ca inherited) (string "inherited: " inherited))
    (def [plain ms-plain] (run-e env show-env))
    (assert (= "unset" plain) (string "a start without TLS exported: " plain))
    (def [tls ms-tls] (run-e env (string "(import jsec/tls) " show-env)))
    (assert (= path tls) (string "importing jsec/tls gave SSL_CERT_FILE " tls))
    (print "ok ca-roots " n " roots from the " ca "; a start takes " ms-plain
           " ms, or " ms-tls " ms with TLS"))
  (unless store
    (assert (not (string/has-prefix? "none found" ca)) (string "no CA bundle: " ca))
    (print "ok ca-roots " ca ", chirp -v in " ms " ms")))
