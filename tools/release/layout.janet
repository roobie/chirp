# Lays out a release from the artifacts CI built, signs it and checks the
# signature against the key chirp trusts. The release workflow publishes the
# result as a GitHub release, the pages workflow as the site's latest tree.
#   chirp layout.janet release <artifacts> <out> --pub <public-key.pem> [--tag <name>] [--key-env <name>]
#       <out> gets the files named chirp-<version>-<target>, NOTICES-<target>.txt,
#       SHA256SUMS and SHA256SUMS.sig. Prints the version, taken from the
#       shipped binary, and nothing else on stdout. The private key is in
#       the variable --key-env names, CHIRP_RELEASE_SIGNING_KEY by default (see
#       sign.janet), and --pub is the matching public key. A tag must name the
#       version.
#   chirp layout.janet version <artifacts>
#       Prints the version of the shipped binary and does nothing else, so a
#       caller can decide whether to lay out and sign at all.
#   chirp layout.janet mirror <release> <tree> <version>
#       <tree> must be empty or absent. Arranges a release as the static tree chirp --self-update reads from a
#       --base: <tree>/latest/download/SHA256SUMS{,.sig} and
#       <tree>/download/v<version>/<every release file>.
(import spork/sh)
(import ./sign)
(import ../../src/chirp/update)

(def- usage "usage: chirp layout.janet release <artifacts> <out> --pub <pem> [--tag <name>] [--key-env <name>] | version <artifacts> | mirror <release> <tree> <version>")
(def- primary-target "linux-x64")
# Published on the site's try page, not as a release file.
(def- unreleased-targets ["wasm32-wasi"])

(defn- die [& msg] (eprint "layout: " ;msg) (os/exit 1))

(def- options ["--pub" "--tag" "--key-env"])

(defn- shipped-version
  "The version the primary binary reports, from `chirp --version`'s first line."
  [artifacts]
  (def exe (string artifacts "/chirp-" primary-target "-a/chirp"))
  # Artifacts do not keep the executable bit.
  (os/chmod exe 8r755)
  (def identity (first (string/split "\n" (sh/exec-slurp exe "--version"))))
  (eprint identity)
  (def [name version] (string/split " " identity))
  (unless (and (= name "chirp") version (not (empty? version)))
    (die "cannot read a version from: " identity))
  version)

(defn- write-sums
  "SHA256SUMS for every file now in `dir`, in sha256sum's format, sorted by name."
  [dir]
  (def sums (buffer))
  (each name (sorted (os/dir dir))
    (buffer/push sums (update/sha256-hex (slurp (string dir "/" name))) "  " name "\n"))
  (spit (string dir "/SHA256SUMS") sums))

(defn- add-target
  "Copies one target's binary and notices into the release directory."
  [from out version target]
  (def windows? (os/stat (string from "/chirp.exe")))
  (def to (string out "/chirp-" version "-" target (if windows? ".exe" "")))
  (sh/copy-file (string from (if windows? "/chirp.exe" "/chirp")) to)
  (os/chmod to 8r755)
  (sh/copy-file (string from "/NOTICES.txt") (string out "/NOTICES-" target ".txt")))

(defn- release [artifacts out pub tag key-env]
  (def version (shipped-version artifacts))
  (when (and tag (not= tag (string "v" version)))
    (die "tag " tag " does not match the binary's version v" version))
  # A rerun into the same directory would list the files and signature of the last.
  (when (and (os/stat out) (not (empty? (os/dir out))))
    (die out " is not empty"))
  (sh/create-dirs out)
  (each dir (sorted (os/dir artifacts))
    (when (and (string/has-prefix? "chirp-" dir) (string/has-suffix? "-a" dir))
      (def target (string/slice dir 6 -3))
      (unless (has-value? unreleased-targets target)
        (add-target (string artifacts "/" dir) out version target))))
  (write-sums out)
  (sign/sign (string out "/SHA256SUMS") (string out "/SHA256SUMS.sig") key-env)
  # A wrong secret would otherwise publish a tree that no chirp accepts.
  (sign/verify (string out "/SHA256SUMS") (string out "/SHA256SUMS.sig") pub)
  (print version))

(defn- mirror [release-dir tree version]
  (when (and (os/stat tree) (not (empty? (os/dir tree))))
    (die tree " is not empty"))
  (def files (string tree "/download/v" version))
  (def sums (string tree "/latest/download"))
  (sh/create-dirs files)
  (sh/create-dirs sums)
  (each name (os/dir release-dir)
    (sh/copy-file (string release-dir "/" name) (string files "/" name)))
  (each name ["SHA256SUMS" "SHA256SUMS.sig"]
    (sh/copy-file (string release-dir "/" name) (string sums "/" name))))

(defn main [_ & args]
  (def opts @{})
  (def positional @[])
  (var i 0)
  (while (< i (length args))
    (def a (args i))
    (if (string/has-prefix? "--" a)
      (do
        (unless (has-value? options a) (die "unknown option " a ". " usage))
        (put opts a (or (get args (++ i)) (die a " needs a value"))))
      (array/push positional a))
    (++ i))
  (case [(first positional) (length positional)]
    ["release" 3]
    (release (positional 1) (positional 2) (or (opts "--pub") (die usage)) (opts "--tag") (opts "--key-env"))
    ["version" 2] (print (shipped-version (positional 1)))
    ["mirror" 4] (mirror (positional 1) (positional 2) (positional 3))
    (die usage)))
