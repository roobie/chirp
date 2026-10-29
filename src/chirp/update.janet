# `chirp --self-update`. The release is a static file tree: a signed SHA256SUMS
# names the binary for each target, so the signature, not the transport, is
# what is trusted, and any mirror can serve the tree.
(import spork-https :as https)
(import jsec/crypto)

(defn- die [& msg] (error (string ;msg)))

(defn- windows? [] (truthy? (index-of (os/which) [:windows :mingw])))

(defn- hex [bytes]
  (string/format (string/repeat "%02x" (length bytes)) ;(string/bytes bytes)))

(defn- sha256-hex [data] (hex (crypto/digest :sha256 data)))

# Versions ----------------------------------------------------------------

(def- version-peg
  ~{:num (<- (some (range "09")))
    :ident (some (+ (range "09" "az" "AZ") "-"))
    :pre (* "-" (<- (* :ident (any (* "." :ident)))))
    :main (* :num "." :num "." :num (? :pre) -1)})

(defn- parse-version
  "[major minor patch pre-release-or-nil] of a semver string, or nil."
  [s]
  (when-let [m (peg/match version-peg s)]
    [;(map scan-number (slice m 0 3)) (get m 3)]))

(defn- numeric? [s] (truthy? (peg/match ~(* (some (range "09")) -1) s)))

# Semver precedence of two pre-release strings: numeric identifiers compare
# as numbers and sort below alphanumeric ones; a prefix is the smaller.
(defn- compare-pre [a b]
  (def xs (string/split "." a))
  (def ys (string/split "." b))
  (var result 0)
  (var i 0)
  (while (and (zero? result) (< i (min (length xs) (length ys))))
    (def [x y] [(xs i) (ys i)])
    (set result
         (cond
           (and (numeric? x) (numeric? y)) (compare (scan-number x) (scan-number y))
           (numeric? x) -1
           (numeric? y) 1
           (compare x y)))
    (++ i))
  (if (zero? result) (compare (length xs) (length ys)) result))

(defn compare-versions
  "-1, 0 or 1 as version string a is older than, equal to or newer than b.
  A pre-release is older than its release."
  [a b]
  (def [pa pb] [(parse-version a) (parse-version b)])
  (assert (and pa pb) "compare-versions needs semver strings")
  (def core (compare (slice pa 0 3) (slice pb 0 3)))
  (cond
    (not= 0 core) core
    (and (pa 3) (pb 3)) (compare-pre (pa 3) (pb 3))
    (pa 3) -1
    (pb 3) 1
    0))

(defn- pre-release? [version] (truthy? (string/find "-" version)))

# SHA256SUMS ---------------------------------------------------------------

# The second separator form is sha256sum's binary-mode marker.
(def- sums-line-peg
  ~(* (<- (repeat 64 (range "09" "af"))) (+ "  " " *") (<- (some 1)) -1))

(defn- parse-sums
  "Table of file name to lowercase hex sha256, from sha256sum-format text.
  Lines that do not parse are left out."
  [text]
  (def out @{})
  (each line (string/split "\n" (string/replace-all "\r" "" text))
    (when-let [[sha name] (peg/match sums-line-peg line)]
      (put out name sha)))
  out)

(defn- release-name
  "Asset name of the binary for a version and target."
  [version target]
  (string "chirp-" version "-" target (if (string/has-prefix? "windows-" target) ".exe" "")))

# The version is read from the signed names, never from anywhere unsigned.
(defn- latest-release
  "[version name sha256] for target from the signed sums, or an error."
  [sums target]
  (def suffix (string "-" target (if (string/has-prefix? "windows-" target) ".exe" "")))
  (def found
    (seq [name :keys sums
          :when (and (string/has-prefix? "chirp-" name) (string/has-suffix? suffix name))
          :let [version (string/slice name 6 (- (length name) (length suffix)))]
          :when (parse-version version)]
      [version name (sums name)]))
  (case (length found)
    0 (die "the signed SHA256SUMS has no binary for " target)
    1 (first found)
    (die "the signed SHA256SUMS names more than one binary for " target)))

# Where things are --------------------------------------------------------------

(defn- target-name [targets]
  (def os (if (= :mingw (os/which)) :windows (os/which)))
  (or (get-in targets [os (os/arch)])
      (die "no release exists for " (os/which) " on " (os/arch))))

(defn- search-path [name]
  (def sep (if (windows?) ";" ":"))
  (def names (if (and (windows?) (not (string/has-suffix? ".exe" name)))
               [(string name ".exe") name]
               [name]))
  (var found nil)
  (each dir (string/split sep (os/getenv "PATH" ""))
    (each n names
      (def p (string dir "/" n))
      (when (and (not found) (not (empty? dir)) (= :file (os/stat p :mode)))
        (set found p))))
  found)

(defn- running-binary []
  (def self (dyn *executable*))
  (def has-sep? (or (string/find "/" self) (and (windows?) (string/find "\\" self))))
  (defn real [path] (when path (let [[ok p] (protect (os/realpath path))] (when ok p))))
  (or (when (= :linux (os/which)) (real "/proc/self/exe"))
      (real (if has-sep? self (search-path self)))
      (die "cannot find the running binary (" self ")")))

# Fetching ------------------------------------------------------------------

(defn- fetch [url user-agent]
  (def res
    (try (https/request "GET" url :max-redirects 10 :headers {"User-Agent" user-agent})
      ([e] (die "cannot fetch " url ": " e))))
  (unless (= 200 (res :status)) (die "cannot fetch " url ": HTTP " (res :status)))
  (string (res :body)))

(defn- verified-sums
  "The text of SHA256SUMS, once its signature verifies against key-pem."
  [base key-pem user-agent]
  (def dir (string base "/latest/download/"))
  (def sums (fetch (string dir "SHA256SUMS") user-agent))
  (def sig (try (fetch (string dir "SHA256SUMS.sig") user-agent)
             ([e] (die "signature missing: " e))))
  (def [ok verdict] (protect (crypto/verify key-pem sums sig)))
  (unless ok (die "cannot check the signature: " verdict))
  (unless verdict (die "signature of SHA256SUMS does not verify; refusing the release"))
  sums)

# Swapping ----------------------------------------------------------------

(defn- install
  "Replace the binary at exe with bytes. On any failure the old binary stays and
  the temporary file is removed."
  [exe bytes]
  (def tmp (string exe ".new"))
  (def old (string exe ".old"))
  (defer (when (os/stat tmp) (os/rm tmp))
    (try (spit tmp bytes)
      ([e] (die "cannot write " tmp ": " e)))
    (unless (windows?) (os/chmod tmp 8r755))
    (if (windows?)
      # A running exe cannot be overwritten but can be renamed away.
      (do
        (try (do (when (os/stat old) (os/rm old))
               (os/rename exe old))
          ([e] (die "cannot move " exe " aside: " e)))
        (try (os/rename tmp exe)
          ([e]
            (os/rename old exe)
            (die "cannot install " exe ": " e))))
      (try (os/rename tmp exe)
        ([e] (die "cannot replace " exe ": " e))))))

# Command -------------------------------------------------------------------

(defn- parse-args [args]
  (def opts @{})
  (var i 0)
  (defn value [flag] (or (get args (++ i)) (die flag " needs a value")))
  (while (< i (length args))
    (def a (args i))
    (case a
      "--check" (put opts :check true)
      "--force" (put opts :force true)
      "--base" (put opts :base (value a))
      "--key" (put opts :key (value a))
      (die "unknown argument " a ". Usage: chirp --self-update [--check] [--force] [--base URL] [--key PEM]"))
    (++ i))
  opts)

(defn- self-update [args {:version version :base default-base :targets targets :key key-pem}]
  (def opts (parse-args args))
  (def base (let [b (or (opts :base) default-base)]
              (if (string/has-suffix? "/" b) (string/slice b 0 -2) b)))
  (def key (if (opts :key)
             (try (slurp (opts :key)) ([e] (die "cannot read key file " (opts :key) ": " e)))
             key-pem))
  (def user-agent (string "chirp/" version))
  (def target (target-name targets))
  (when (and (not (opts :check)) (pre-release? version) (not (opts :force)))
    (die "this is chirp " version ", a pre-release build from main, not a release. "
         "Releases are what --self-update installs; use --force to replace it anyway"))
  (def sums-text (verified-sums base key user-agent))
  (def [latest name sha] (latest-release (parse-sums sums-text) target))
  (def newer? (pos? (compare-versions latest version)))
  (cond
    (opts :check)
    (do (print "current " version)
        (print "latest  " latest)
        (print "target  " target)
        (print "update available: " (if newer? "yes" "no")))

    (not newer?)
    (print "chirp " version " is up to date (latest release: " latest ")")

    (do
      (def exe (running-binary))
      # A leftover from an earlier Windows update; it may still be locked.
      (when (windows?) (protect (when (os/stat (string exe ".old")) (os/rm (string exe ".old")))))
      (def bytes (fetch (string base "/download/v" latest "/" name) user-agent))
      (def got (sha256-hex bytes))
      (unless (= got sha)
        (die name " does not match the signed checksum (got " got ", expected " sha ")"))
      (install exe bytes)
      (print "updated chirp " version " -> " latest " at " exe))))

(defn run
  "Run `chirp --self-update`. args are the words after it; config has :version,
  :base, :targets and :key (the public key as PEM). Failures print to stderr and
  exit 1, leaving the running binary as it was."
  [args config]
  (def [ok err] (protect (self-update args config)))
  (unless ok
    (eprint "chirp --self-update: " err)
    (os/exit 1)))
