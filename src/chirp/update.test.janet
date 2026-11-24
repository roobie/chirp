# Run: chirp src/chirp/update.test.janet
# The pure parts of self-update: version order, the signed sums, and which
# release they name. What it fetches and replaces is test/smoke/self-update.janet's.
(import ./update)

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

# Version order, oldest first. Each must be older than every one after it.
(def ordered
  ["0.9.9" "0.10.0-dev" "0.10.0" "0.10.1" "1.0.0-1" "1.0.0-2" "1.0.0-10" "1.0.0-alpha"
   "1.0.0-alpha.1" "1.0.0-alpha.beta" "1.0.0-beta" "1.0.0-rc.1" "1.0.0" "1.0.1-dev" "2.0.0"])
(loop [i :range [0 (length ordered)] j :range [0 (length ordered)]]
  (check (string (ordered i) " vs " (ordered j))
         (update/compare-versions (ordered i) (ordered j))
         (compare i j)))
# Numbers compare as numbers, not text.
(check "0.9.0 < 0.13.0" (update/compare-versions "0.9.0" "0.13.0") -1)
(fails "not semver" |(update/compare-versions "1.0" "1.0.0") "semver")
(fails "leading v" |(update/compare-versions "v1.0.0" "1.0.0") "semver")

(def a (string/repeat "a" 64))
(def b (string/repeat "b" 64))
(check "sums: text and binary markers, CRLF, junk left out"
       (update/parse-sums (string a "  chirp-1.2.3-linux-x64\r\n"
                                  b " *chirp-1.2.3-windows-x64.exe\n"
                                  "not a sum line\n"
                                  (string/repeat "A" 64) "  UPPERCASE-HEX\n"
                                  "abc  too-short\n\n"))
       @{"chirp-1.2.3-linux-x64" a "chirp-1.2.3-windows-x64.exe" b})
(check "sums: a name may hold spaces"
       (update/parse-sums (string a "  NOTICES linux.txt\n"))
       @{"NOTICES linux.txt" a})

(def sums {"chirp-1.2.3-linux-x64" a
           "chirp-1.2.3-linux-arm64" b
           "chirp-1.2.3-windows-x64.exe" b
           "NOTICES-linux-x64.txt" b
           "SHA256SUMS" b})
(check "latest: linux" (update/latest-release sums "linux-x64") ["1.2.3" "chirp-1.2.3-linux-x64" a])
(check "latest: windows takes the .exe"
       (update/latest-release sums "windows-x64") ["1.2.3" "chirp-1.2.3-windows-x64.exe" b])
(check "latest: a pre-release version is read whole"
       (update/latest-release {"chirp-0.14.0-dev-linux-x64" a} "linux-x64")
       ["0.14.0-dev" "chirp-0.14.0-dev-linux-x64" a])
(fails "latest: no binary for the target" |(update/latest-release sums "macos-arm64") "no binary for macos-arm64")
(fails "latest: two versions for one target"
       |(update/latest-release (merge sums {"chirp-1.2.4-linux-x64" b}) "linux-x64") "more than one")
(fails "latest: a name that is not a version does not count"
       |(update/latest-release {"chirp-latest-linux-x64" a} "linux-x64") "no binary")

(check "sha256 of the empty string" (update/sha256-hex "")
       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

# Which base and key a set of flags trusts. That each key verifies only its own
# tree is shown with real keys in test/smoke/self-update.janet.
(def config {:base "https://example.test/releases" :key "RELEASE"
             :channels {:main {:base "https://example.test/latest" :key "MAIN"}
                        :keyless {:base "https://example.test/keyless"}}})
(check "trust: default" (update/resolve-trust {} config)
       {:base "https://example.test/releases" :key "RELEASE"})
(check "trust: channel brings its own base and key" (update/resolve-trust {:channel "main"} config)
       {:base "https://example.test/latest" :key "MAIN"})
(check "trust: --base keeps the release key, trailing slash dropped"
       (update/resolve-trust {:base "https://mirror.test/x/"} config)
       {:base "https://mirror.test/x" :key "RELEASE"})
(check "trust: --channel with --base keeps the channel's key"
       (update/resolve-trust {:channel "main" :base "https://mirror.test/y"} config)
       {:base "https://mirror.test/y" :key "MAIN"})
(fails "trust: unknown channel" |(update/resolve-trust {:channel "nightly"} config) "unknown channel nightly")
(fails "trust: a channel without a key never falls back to the release key"
       |(update/resolve-trust {:channel "keyless"} config) "has no key")
(fails "trust: unreadable --key" |(update/resolve-trust {:key "/no/such/key.pem"} config) "cannot read key file")

(when (pos? failures)
  (eprintf "update tests: %d failed" failures)
  (os/exit 1))
(print "update tests: ok")
