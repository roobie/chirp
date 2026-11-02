# gzip is linked into the binary: gzip framing over miniz, whole or in pieces.
(import gzip)
(import spork/base64)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

(defn- in-pieces
  "Run bytes through compressor or decompressor z, n bytes at a time."
  [z bytes n]
  (def out @"")
  (var i 0)
  (while (< i (length bytes))
    (gzip/update z (string/slice bytes i (min (length bytes) (+ i n))) out)
    (+= i n))
  (gzip/finish z out))

# Two members written by GNU gzip: `gzip -9c nm.txt` (holding "abc", so its
# header carries the name and an mtime) then `printf 'def\n' | gzip -1n`.
(def- gnu-gzip (base64/decode "H4sICNDU52oCA25tLnR4dABLTEoGAMJBJDUDAAAAH4sIAAAAAAAEA0tJTeMCALyTbggEAAAA"))

(defn main [&]
  (assert (= "11.0.1" (gzip/version)) "version")
  (def data (string/repeat "chirp-gzip-roundtrip " 50000))
  (def gz (gzip/compress data))
  (assert (< (length gz) (length data)) "compression shrinks the input")
  (assert (= "\x1f\x8b\x08" (string/slice gz 0 3)) "a gzip header")
  (assert (= data (string (gzip/decompress gz))) "round trip")
  (assert (deep= gz (gzip/compress data)) "equal input, equal output")
  (assert (= "" (string (gzip/decompress (gzip/compress "")))) "empty data")
  (each level [0 1 9]
    (assert (= data (string (gzip/decompress (gzip/compress data level)))) (string "level " level)))
  (def into @"x")
  (assert (= into (gzip/compress "" 6 into)) "into is returned")
  (assert (= "x\x1f\x8b" (string/slice into 0 3)) "into is appended to")

  # In pieces: every split of the stream gives the same result.
  (each n [1 7 512 100000]
    (assert (= data (string (in-pieces (gzip/decompressor) gz n))) (string "decompress in pieces of " n))
    (assert (= data (string (gzip/decompress (in-pieces (gzip/compressor) data n))))
            (string "compress in pieces of " n)))

  # Interop: GNU gzip's members are read, its name field skipped.
  (assert (= "abcdef\n" (string (gzip/decompress gnu-gzip))) "GNU gzip, two members")
  (assert (= "abcdef\n" (string (in-pieces (gzip/decompressor) gnu-gzip 3))) "GNU gzip in pieces")

  # Damage is an error, never silently short output.
  (fails |(gzip/decompress (string/slice gz 0 -2)) "truncated")
  (fails |(gzip/decompress (string/slice gz 0 100)) "truncated")
  (fails |(gzip/decompress (string gz "x")) "trailing data")
  (def flipped (buffer gz))
  (put flipped (- (length gz) 6) (bxor 1 (flipped (- (length gz) 6))))
  (fails |(gzip/decompress flipped) "CRC-32 mismatch")
  (def bad-body (buffer gz))
  (put bad-body 10 0xff)
  (fails |(gzip/decompress bad-body) "corrupt")
  (fails |(gzip/decompress "plain text") "not gzip data")
  (fails |(gzip/decompress "") "no data")
  (fails |(gzip/compress "x" 10) "level must be")
  (def done (gzip/compressor))
  (gzip/finish done)
  (fails |(gzip/update done "x") "already finished")
  (fails |(gzip/update "x" "y") "expected a gzip/compressor")

  # Our output is read by the system's gzip, where there is one.
  (def [found sys] (protect
                     (def p (os/spawn ["gzip" "-dc"] :p {:in :pipe :out :pipe}))
                     (def [_ out] (ev/gather (do (ev/write (p :in) gz) (ev/close (p :in)))
                                             (ev/read (p :out) :all)))
                     [(os/proc-wait p) out]))
  (when found
    (assert (= 0 (sys 0)) "system gzip rejects our output")
    (assert (= data (string (sys 1))) "system gzip reads other data"))
  (print "ok gzip " (length data) " -> " (length gz)
         (if found ", read by system gzip" ", no system gzip")))
