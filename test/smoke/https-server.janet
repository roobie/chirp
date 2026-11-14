# A spork-https server in this binary answers HTTPS requests. The self-signed
# certificate is generated here; verification stays on, so an untrusting
# client must fail and a client trusting that certificate must succeed.
# Usage: chirp https-server.janet
#        chirp https-server.janet probe <ca.pem> <ca-port> <other-port>
(import spork-https :as https)
(import jsec/ca)
(import jsec/cert)

(def- exe (let [e (dyn *executable*) [ok p] (protect (os/realpath e))] (if ok p e)))

(defn- handler [req]
  (def ua ((req :headers) "user-agent"))
  {:status 200
   :headers {"Content-Type" "text/plain"}
   # A duplicated header would arrive as an array.
   :body (if (= "/ua" (req :path))
           (if (string? ua) ua "not a single value")
           (string "hello " (req :path)))})

(defn- trusted? [port & opts]
  (first (protect (https/get (string "https://localhost:" port "/smoke") ;opts))))

(defn- temp-pem [pem]
  (def dir (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") "."))
  (def path (string dir "/chirp-smoke-" (os/time) "-" (math/floor (* 1e6 (math/random))) ".pem"))
  (spit path pem)
  path)

(defn- probe
  "Run in a child whose system store (SSL_CERT_FILE) trusts only the other
  server, so that only a :ca that replaces the store refuses it."
  [ca-path ca-port other-port]
  (def ca-pem (slurp ca-path))
  (each [what ok] [["other server, no :ca" (trusted? other-port)]
                    ["ca server, no :ca" (not (trusted? ca-port))]
                    ["ca server, :ca path" (trusted? ca-port :tls-opts {:ca ca-path})]
                    ["ca server, :ca pem" (trusted? ca-port :tls-opts {:ca ca-pem})]
                    ["other server, :ca path" (not (trusted? other-port :tls-opts {:ca ca-path}))]]
    (print (if ok "ok " "FAIL ") what)))

(defn- ca-only
  "Checks, in a child, that :ca trusts the private CA's server and nothing the
  system store trusts."
  [other-cert other-port]
  (def private (ca/generate {:common-name "chirp smoke CA" :days-valid 1}))
  (def issued (ca/issue private {:common-name "localhost" :san ["DNS:localhost"]
                                 :days-valid 1 :extended-key-usage "serverAuth"}))
  (def port (string (+ 1 (scan-number other-port))))
  (def server (https/server handler (issued :cert) (issued :key) "localhost" port))
  (def ca-path (temp-pem (ca/get-cert private)))
  (def store-path (temp-pem other-cert))
  (def out
    (defer (do (:close server) (os/rm ca-path) (os/rm store-path))
      (ev/sleep 0.2)
      (def p (os/spawn [exe (dyn *current-file*) "probe" ca-path port other-port]
                       :pe (merge (os/environ) {"SSL_CERT_FILE" store-path :out :pipe})))
      (def out (string (ev/read (p :out) :all)))
      (assert (= 0 (os/proc-wait p)) (string "probe failed: " out))
      out))
  (assert (not (or (os/stat ca-path) (os/stat store-path))) "pem files are deleted")
  (assert (not (string/find "FAIL" out)) out))

(defn main [_ &opt mode & args]
  (when (= "probe" mode) (probe ;args) (os/exit 0))
  (def certs (cert/generate-self-signed-cert
               {:common-name "localhost" :organization "chirp smoke"
                :country "US" :days-valid 1 :bits 2048}))
  (def port (string (+ 20000 (math/rng-int (math/rng (os/time)) 20000))))
  (def url (string "https://localhost:" port "/smoke"))
  (def server (https/server handler (certs :cert) (certs :key) "localhost" port))
  (defer (:close server)
    (ev/sleep 0.2)
    (assert (not (trusted? port)) "untrusted certificate was accepted")
    # jsec's client takes the trusted certificate as PEM data, not a path.
    (def res (https/get url :tls-opts {:trusted-cert (certs :cert)}))
    (assert (= 200 (res :status)) (string "status " (res :status)))
    (assert (= "hello /smoke" (string (res :body))) "unexpected body")
    (print "ok https-server " url " status " (res :status))

    # The chirp overlay: default User-Agent, and the caller's User-Agent kept
    # as the only one.
    (def ua-url (string "https://localhost:" port "/ua"))
    (defn ua-of [& opts]
      (string ((https/get ua-url :tls-opts {:trusted-cert (certs :cert)} ;opts) :body)))
    (def default-ua (ua-of))
    (assert (string/has-prefix? "chirp/" default-ua) (string "default user-agent: " default-ua))
    (def own-ua (ua-of :headers {"user-agent" "x"}))
    (assert (= "x" own-ua) (string "explicit user-agent: " own-ua))
    (print "ok https-overlay user-agent " default-ua ", explicit " own-ua)

    (ca-only (certs :cert) port)
    (print "ok https-ca :ca trusts its own CA's server and refuses one the system store trusts")))
