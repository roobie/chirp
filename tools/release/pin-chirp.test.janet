# Run from the repo root: chirp tools/release/pin-chirp.test.janet
(import ./pin-chirp)

(var failures 0)
(defn- check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))
(defn- fails [name f needle]
  (def [ok err] (protect (f)))
  (unless (and (not ok) (string/find needle (string err)))
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want an error holding: %s" name [ok err] needle)))

(def a (string/repeat "a" 64))
(def b (string/repeat "b" 64))
(def base "https://example.test/releases")

(check "the asset is the linux-x64 binary of that version"
       (pin-chirp/asset base "1.2.3" (string b "  chirp-1.2.3-linux-arm64\n" a "  chirp-1.2.3-linux-x64\n"))
       ["https://example.test/releases/download/v1.2.3/chirp-1.2.3-linux-x64" a])
(fails "sums of another version" |(pin-chirp/asset base "1.2.4" (string a "  chirp-1.2.3-linux-x64\n"))
       "does not name chirp-1.2.4-linux-x64")

(def before
  (string "{:image \"alpine@sha256:00\"\n"
          " # a comment that mentions :chirp {\n"
          " :chirp {:version \"1.0.0\" :url \"https://old.test/chirp\" :sha256 \"" b "\"}\n"
          " :zig {:version \"0.1.0\" :url \"https://z.test/z\" :sha256 \"cc\"}}\n"))
(def after (pin-chirp/repin before "1.2.3" "https://new.test/chirp" a))
(check "only the pin's line changes"
       after
       (string "{:image \"alpine@sha256:00\"\n"
               " # a comment that mentions :chirp {\n"
               " :chirp {:version \"1.2.3\" :url \"https://new.test/chirp\" :sha256 \"" a "\"}\n"
               " :zig {:version \"0.1.0\" :url \"https://z.test/z\" :sha256 \"cc\"}}\n"))
(check "the result still parses, with the new pin"
       ((parse after) :chirp) {:version "1.2.3" :url "https://new.test/chirp" :sha256 a})
(check "a pin on the last line keeps the table closed"
       (parse (pin-chirp/repin "{:a \"x\"\n :chirp {:version \"1.0.0\" :url \"u\" :sha256 \"s\"}}\n" "2.0.0" "v" "t"))
       {:a "x" :chirp {:version "2.0.0" :url "v" :sha256 "t"}})
(fails "no pin" |(pin-chirp/repin "{:a \"x\"}\n" "1.2.3" "u" a) "exactly one :chirp pin")

# The real file: repinning it to what it already holds changes nothing.
(def real (string (slurp "pins.jdn")))
(def pin ((parse real) :chirp))
(check "pins.jdn round-trips" (pin-chirp/repin real (pin :version) (pin :url) (pin :sha256)) real)

(when (pos? failures)
  (eprintf "pin-chirp tests: %d failed" failures)
  (os/exit 1))
(print "pin-chirp tests: ok")
