# Move the :chirp pin, the released chirp that runs the repo checks in CI, to a
# published release. It reads the release's signed SHA256SUMS, checks the
# signature against the release key in this tree, and rewrites the pin's line
# in pins.jdn. Like cut.janet it only edits; the commit stays a human step.
#   chirp tools/release/pin-chirp.janet X.Y.Z [--root DIR]

(import spork-https :as https)
(import jsec/crypto)
(import ../../src/chirp/update)

(def- target "linux-x64")

(defn- die [& msg] (eprint "pin-chirp: " ;msg) (os/exit 1))

(defn repin
  "The text of pins.jdn with its :chirp pin naming this version, url and sha256.
  Errors unless the text holds exactly one :chirp line."
  [text version url sha]
  (def lines (string/split "\n" text))
  (def hits (filter |(string/has-prefix? " :chirp {" (lines $)) (range (length lines))))
  (unless (= 1 (length hits)) (errorf "expected exactly one :chirp pin in pins.jdn, found %d" (length hits)))
  (def old (lines (first hits)))
  # The last pin's line also closes the file's table.
  (def close (if (string/has-suffix? "}}" old) "}}" "}"))
  (put lines (first hits)
       (string/format " :chirp {:version %j :url %j :sha256 %j%s" version url sha close))
  (string/join lines "\n"))

(defn asset
  "[url sha256] of the checks' binary in a release, from its base URL, its
  version and the text of its SHA256SUMS. Errors when the sums do not name it."
  [base version sums-text]
  (def name (string "chirp-" version "-" target))
  (def sha (get (update/parse-sums sums-text) name))
  (unless sha (errorf "SHA256SUMS of %s does not name %s" version name))
  [(string base "/download/v" version "/" name) sha])

(defn- fetch [url]
  (def res (try (https/request "GET" url :max-redirects 10)
             ([e] (die "cannot fetch " url ": " e))))
  (unless (= 200 (res :status)) (die "cannot fetch " url ": HTTP " (res :status)))
  (string (res :body)))

(defn main [_ & args]
  (var root ".")
  (var version nil)
  (var i 0)
  (while (< i (length args))
    (def a (args i))
    (cond
      (= a "--root") (set root (or (get args (++ i)) (die "--root needs a directory")))
      version (die "unexpected argument " a)
      (set version a))
    (++ i))
  (unless (and version (peg/match ~(* :d+ "." :d+ "." :d+ -1) version))
    (die "usage: pin-chirp.janet X.Y.Z [--root DIR]"))
  (def config (parse (slurp (string root "/src/chirp/chirp.jdn"))))
  (def base (get-in config [:update :base]))
  (def key (slurp (string root "/src/chirp/" (get-in config [:update :key]))))
  (def dir (string base "/download/v" version "/"))
  (def sums (fetch (string dir "SHA256SUMS")))
  (def sig (fetch (string dir "SHA256SUMS.sig")))
  (unless (crypto/verify key sums sig)
    (die "SHA256SUMS of " version " does not verify against the release key; pins.jdn is unchanged"))
  (def [url sha] (asset base version sums))
  (def path (string root "/pins.jdn"))
  (spit path (repin (slurp path) version url sha))
  (print "edited: " path)
  (print ":chirp is " version " (" sha ")"))
