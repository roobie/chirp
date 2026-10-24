# spork/zip is linked into the binary: compress then decompress round-trips.
(import spork/zip)

(defn main [&]
  (def data (string/repeat "chirp-zip-roundtrip " 5000))
  (def packed (zip/compress data))
  (assert (< (length packed) (length data)) "compression shrinks the input")
  (assert (= data (string (zip/decompress packed))) "round trip differs")
  (print "ok zip " (length data) " -> " (length packed) " -> " (length data)))
