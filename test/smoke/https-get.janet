# HTTPS GET to a real public host with certificate verification on.
# Usage: chirp https-get.janet [url]
(import spork-https :as https)

(defn main [& args]
  (def url (get args 1 "https://example.com/"))
  (def res (https/get url))
  (assert (= 200 (res :status)) (string "status " (res :status)))
  (assert (string/find "Example Domain" (res :body)) "unexpected body")
  (print "ok https-get " url " status " (res :status)))
