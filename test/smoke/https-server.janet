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
    (https/server (fn [req] {:status 200
                             :headers {"Content-Type" "text/plain"}
                             :body (string "hello " (req :path))})
                  (certs :cert) (certs :key) "localhost" port))
  (defer (:close server)
    (ev/sleep 0.2)
    (def [untrusted-ok _] (protect (https/get url)))
    (assert (not untrusted-ok) "untrusted certificate was accepted")
    # jsec's client takes the trusted certificate as PEM data, not a path.
    (def res (https/get url :tls-opts {:trusted-cert (certs :cert)}))
    (assert (= 200 (res :status)) (string "status " (res :status)))
    (assert (= "hello /smoke" (string (res :body))) "unexpected body")
    (print "ok https-server " url " status " (res :status))))
