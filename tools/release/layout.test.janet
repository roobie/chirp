# Run from the repo root: chirp tools/release/layout.test.janet
# Lays out fake artifacts with a throwaway key, so the script runs end to end.

(import jsec/crypto)
(import spork/sh)

(def script (string (os/cwd) "/tools/release/layout.janet"))
(def chirp (dyn :executable))
(def base (or (os/getenv "TMPDIR") "/tmp"))
(def root (string base "/chirp-layout-" (os/getpid)))

(var failures 0)
(defn check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(def key-var "CHIRP_RELEASE_SIGNING_KEY")

(defn run
  "Runs a command with the signing key set to `signing` (nil leaves it unset),
  then puts the variable back."
  [signing & args]
  (def before (os/getenv key-var))
  (os/setenv key-var signing)
  (defer (os/setenv key-var before)
    (def p (os/spawn args :p {:out :pipe :err :pipe}))
    (def out (ev/read (p :out) :all))
    (def err (ev/read (p :err) :all))
    [(os/proc-wait p) (string out) (string err)]))

(defer (sh/rm root)
  (def key (crypto/generate-key :ed25519))
  (def other-key (crypto/generate-key :ed25519))
  (def work root)
  (sh/create-dirs work)
  (def pub (string work "/pub.pem"))
  (spit pub (crypto/export-public-key key))

  (def version "0.9.0-dev")
  (def artifacts (string work "/artifacts"))
  (each target ["linux-x64" "windows-x64" "macos-arm64" "wasm32-wasi"]
    (def dir (string artifacts "/chirp-" target "-a"))
    (sh/create-dirs dir)
    (def exe (string dir (if (= target "windows-x64") "/chirp.exe" "/chirp")))
    (spit exe (string "#!/bin/sh\necho 'chirp " version " (fake) on Janet'\necho second line\n# " target "\n"))
    (spit (string dir "/NOTICES.txt") (string "notices for " target "\n")))

  (def expected-files
    (sorted ["SHA256SUMS" "SHA256SUMS.sig" "NOTICES-linux-x64.txt" "NOTICES-windows-x64.txt"
             "NOTICES-macos-arm64.txt" (string "chirp-" version "-linux-x64")
             (string "chirp-" version "-windows-x64.exe") (string "chirp-" version "-macos-arm64")]))

  (def out (string work "/release"))
  (def [code stdout stderr] (run key chirp script "release" artifacts out "--pub" pub "--tag" (string "v" version)))
  (check "release: exit" [code stderr] [0 stderr])
  (check "release: prints only the version" stdout (string version "\n"))
  (check "release: files" (sorted (os/dir out)) expected-files)
  (check "release: no wasm" (os/stat (string out "/NOTICES-wasm32-wasi.txt")) nil)

  # The listing is what sha256sum itself accepts, and names every file but itself and its signature.
  (let [[sumcode _ sumerr] (run nil "sh" "-c" (string "cd " out " && sha256sum -c SHA256SUMS"))]
    (check "release: sha256sum accepts SHA256SUMS" [sumcode sumerr] [0 ""]))
  (check "release: listing names"
         (map |(last (string/split "  " $)) (string/split "\n" (string/trim (slurp (string out "/SHA256SUMS")))))
         (sorted (filter |(not (string/has-prefix? "SHA256SUMS" $)) expected-files)))
  (check "release: signature verifies"
         (crypto/verify (slurp pub) (slurp (string out "/SHA256SUMS")) (slurp (string out "/SHA256SUMS.sig"))) true)

  (let [[c _ e] (run key chirp script "release" artifacts (string work "/tagless") "--pub" pub)]
    (check "no tag: exit" [c e] [0 e]))
  (let [[c _ e] (run key chirp script "release" artifacts (string work "/badtag") "--pub" pub "--tag" "v9.9.9")]
    (check "wrong tag: exit" c 1)
    (check "wrong tag: reason" (truthy? (string/find "does not match the binary's version" e)) true))
  (let [[c _ e] (run nil chirp script "release" artifacts (string work "/nokey") "--pub" pub)]
    (check "no key: exit" (not= c 0) true)
    (check "no key: reason" (truthy? (string/find "CHIRP_RELEASE_SIGNING_KEY is not set" e)) true))
  (let [[c _ e] (run other-key chirp script "release" artifacts (string work "/wrongkey") "--pub" pub)]
    (check "wrong key: exit" (not= c 0) true)
    (check "wrong key: reason" (truthy? (string/find "does not verify against" e)) true))

  # A second key in a variable of its own, as main builds use.
  (let [main-var "CHIRP_TEST_MAIN_KEY"
        main-key (crypto/generate-key :ed25519)
        main-pub (string work "/main-pub.pem")
        main-out (string work "/main-release")]
    (spit main-pub (crypto/export-public-key main-key))
    (os/setenv main-var main-key)
    (defer (os/setenv main-var nil)
      (let [[c _ e] (run nil chirp script "release" artifacts main-out "--pub" main-pub "--key-env" main-var)]
        (check "key-env: exit" [c e] [0 e])
        (check "key-env: verifies with its own key"
               (crypto/verify (slurp main-pub) (slurp (string main-out "/SHA256SUMS")) (slurp (string main-out "/SHA256SUMS.sig"))) true)
        (check "key-env: not with the other"
               (crypto/verify (slurp pub) (slurp (string main-out "/SHA256SUMS")) (slurp (string main-out "/SHA256SUMS.sig"))) false)))
    (let [[c _ e] (run key chirp script "release" artifacts (string work "/wrong-var") "--pub" pub "--key-env" "CHIRP_NOT_SET_VAR")]
      (check "key-env unset: exit" c 1)
      (check "key-env unset: names the variable" (truthy? (string/find "CHIRP_NOT_SET_VAR is not set" e)) true)))

  # A dry run signs with a key of its own and needs no key or public key.
  (let [dry-out (string work "/throwaway")
        [c so e] (run nil chirp script "release" artifacts dry-out "--throwaway")]
    (check "throwaway: exit" [c e] [0 e])
    (check "throwaway: prints only the version" so (string version "\n"))
    (check "throwaway: files" (sorted (os/dir dry-out)) expected-files)
    (check "throwaway: sha256sum accepts SHA256SUMS"
           (first (run nil "sh" "-c" (string "cd " dry-out " && sha256sum -c SHA256SUMS"))) 0)
    (check "throwaway: not signed by the real key"
           (crypto/verify (slurp pub) (slurp (string dry-out "/SHA256SUMS")) (slurp (string dry-out "/SHA256SUMS.sig"))) false)
    (check "throwaway: no private key on stderr" (truthy? (string/find "PRIVATE" e)) false)
    (check "throwaway: no private key left behind"
           (truthy? (find |(string/find "PRIVATE" (slurp (string dry-out "/" $))) (os/dir dry-out))) false))
  (let [[c _ e] (run key chirp script "release" artifacts (string work "/mixed") "--throwaway" "--pub" pub)]
    (check "throwaway with --pub: exit" c 1)
    (check "throwaway with --pub: usage" (truthy? (string/find "usage:" e)) true))

  (let [[c _ e] (run key chirp script "release" artifacts out "--pub" pub)]
    (check "non-empty out: exit" c 1)
    (check "non-empty out: reason" (truthy? (string/find "is not empty" e)) true))
  (let [[c _ e] (run key chirp script "release" artifacts (string work "/badopt") "--pub" pub "--taag" "v1")]
    (check "unknown option: exit" c 1)
    (check "unknown option: reason" (truthy? (string/find "unknown option --taag" e)) true))

  # sign.janet by itself: stray arguments and a malformed --key-env must fail
  # without signing, and never fall back to the release key.
  (def sums-file (string work "/sums-file"))
  (spit sums-file "x\n")
  (def sign-script (string (os/cwd) "/tools/release/sign.janet"))
  (each [name args] [["sign: --key-env without a value" ["sign" sums-file (string work "/s1") "--key-env"]]
                     ["sign: stray argument" ["sign" sums-file (string work "/s2") "extra"]]
                     ["sign: unknown option" ["sign" sums-file (string work "/s3") "--key" "X"]]]
    (let [[c _ e] (run key chirp sign-script ;args)]
      (check (string name ": exit") c 1)
      (check (string name ": usage") (truthy? (string/find "usage" e)) true)
      (check (string name ": nothing signed") (os/stat (string work "/s" (last (string/split "/s" (args 2))))) nil)))

  (let [[c _ e] (run key chirp script "release" artifacts (string work "/stray") "extra" "--pub" pub)]
    (check "stray argument: exit" c 1)
    (check "stray argument: usage" (truthy? (string/find "usage" e)) true))

  (def tree (string work "/tree"))
  (let [[c _ e] (run nil chirp script "mirror" out tree version)]
    (check "mirror: exit" [c e] [0 e])
    (check "mirror: files under download" (sorted (os/dir (string tree "/download/v" version))) expected-files)
    (check "mirror: sums for self-update" (sorted (os/dir (string tree "/latest/download")))
           @["SHA256SUMS" "SHA256SUMS.sig"])
    (check "mirror: same sums" (slurp (string tree "/latest/download/SHA256SUMS"))
           (slurp (string out "/SHA256SUMS"))))
  (let [[c _ e] (run nil chirp script "mirror" out tree version)]
    (check "mirror into a non-empty tree: exit" c 1)
    (check "mirror into a non-empty tree: reason" (truthy? (string/find "is not empty" e)) true))
  (let [[c o e] (run nil chirp script "version" artifacts)]
    (check "version: exit" [c e] [0 e])
    (check "version: only the version" o (string version "\n"))))

(if (zero? failures)
  (print "release layout tests: ok")
  (do (eprintf "release layout tests: %d failure(s)" failures) (os/exit 1)))
