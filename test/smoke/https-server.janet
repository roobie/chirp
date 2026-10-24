# A spork-https server in this binary answers HTTPS requests. The self-signed
# certificate is generated here; verification stays on, so an untrusting
# client must fail and a client trusting that certificate must succeed.
(import spork-https :as https)
(import jsec/cert)

(defn main [&]
  (def certs (cert/generate-self-signed-cert
               {:common-name "localhost" :organization "chirp smoke"
                :country "US" :days-valid 1 :bits 2048}))
  (def port (string (+ 20000 (math/rng-int (math/rng (os/time)) 20000))))
  (def url (string "https://localhost:" port "/smoke"))
  (def server
    (https/server (fn [req]
                    (def ua ((req :headers) "user-agent"))
                    {:status 200
                     :headers {"Content-Type" "text/plain"}
                     # A duplicated header would arrive as an array.
                     :body (if (= "/ua" (req :path))
                             (if (string? ua) ua "not a single value")
                             (string "hello " (req :path)))})
                  (certs :cert) (certs :key) "localhost" port))
  (defer (:close server)
    (ev/sleep 0.2)
    (def [untrusted-ok _] (protect (https/get url)))
    (assert (not untrusted-ok) "untrusted certificate was accepted")
    # jsec's client takes the trusted certificate as PEM data, not a path.
    (def res (https/get url :tls-opts {:trusted-cert (certs :cert)}))
    (assert (= 200 (res :status)) (string "status " (res :status)))
    (assert (= "hello /smoke" (string (res :body))) "unexpected body")
    (print "ok https-server " url " status " (res :status))

    # The chirp overlay: default User-Agent, caller's User-Agent kept as the
    # only one, and :ca honoured by the client.
    (def ua-url (string "https://localhost:" port "/ua"))
    (defn ua-of [& opts]
      (string ((https/get ua-url :tls-opts {:trusted-cert (certs :cert)} ;opts) :body)))
    (def default-ua (ua-of))
    (assert (string/has-prefix? "chirp/" default-ua) (string "default user-agent: " default-ua))
    (def own-ua (ua-of :headers {"user-agent" "x"}))
    (assert (= "x" own-ua) (string "explicit user-agent: " own-ua))
    (def dir (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") "."))
    (def ca-path (string dir "/chirp-smoke-" (os/time) "-" (math/floor (* 1e6 (math/random))) ".pem"))
    (spit ca-path (certs :cert))
    (def ca-res
      (defer (os/rm ca-path)
        (https/get url :tls-opts {:ca ca-path})))
    (assert (not (os/stat ca-path)) "ca file is deleted")
    (assert (= 200 (ca-res :status)) (string "status with :ca " (ca-res :status)))
    (print "ok https-overlay user-agent " default-ua ", explicit " own-ua ", :ca trusted")))
