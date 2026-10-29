# `chirp self-update` against a mirror served from this process. The release key
# is generated here, and only a copy of the binary under test is ever replaced.
(import spork/http)
(import spork/sh)
(import jsec/crypto)

(def targets ["linux-x64" "linux-arm64" "macos-arm64" "windows-x64"])
(def windows? (truthy? (index-of (os/which) [:windows :mingw])))

(defn- asset [version target]
  (string "chirp-" version "-" target (if (= target "windows-x64") ".exe" "")))

(defn- fake-binary [target] (string "not a real chirp for " target "\n"))

(defn- hex [bytes]
  (string/format (string/repeat "%02x" (length bytes)) ;(string/bytes bytes)))

(defn- run-copy
  "Run the copy with args under a deadline. Returns [exit stdout stderr] with
  carriage returns removed."
  [exe & args]
  (def p (os/spawn [exe ;args] :p {:out :pipe :err :pipe}))
  (def [out err]
    (try (ev/with-deadline 60 (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
      ([_] (os/proc-kill p true) [nil "killed after 60s"])))
  [(os/proc-wait p)
   (string/replace-all "\r" "" (string out))
   (string/replace-all "\r" "" (string err))])

(defn main [&]
  (def tmp (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") ".")
                   "/chirp-smoke-update-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs tmp)
  (defer (sh/rm tmp)
    (def release-key (crypto/generate-key :ed25519))
    (def other-key (crypto/generate-key :ed25519))
    (def key-file (string tmp "/release-key.pem"))
    (spit key-file (crypto/export-public-key release-key))

    (def exe (string tmp "/chirp-copy" (if windows? ".exe" "")))
    (def original (string (slurp (dyn *executable*))))
    (spit exe original)
    (unless windows? (os/chmod exe 8r755))
    (defn unchanged? [] (= original (string (slurp exe))))
    (def [_ identity _] (run-copy exe "-v"))
    (def pre-release? (truthy? (peg/match ~(* "chirp " (some (range "09")) "." (some (range "09")) "."
                                              (some (range "09")) "-")
                                          identity)))

    # The mirror tree, as paths to bytes; publish fills it with a signed release.
    (def tree @{})
    (defn publish [&named version signer]
      (default version "99.0.0")
      (default signer release-key)
      (def sums (string/join
                  (seq [t :in targets]
                    (string (hex (crypto/digest :sha256 (fake-binary t))) "  " (asset version t) "\n"))
                  ""))
      (put tree "/latest/download/SHA256SUMS" sums)
      (put tree "/latest/download/SHA256SUMS.sig" (crypto/sign signer sums))
      (each t targets (put tree (string "/download/v" version "/" (asset version t)) (fake-binary t))))
    (publish)

    (def port (string (+ 20000 (math/rng-int (math/rng (os/time)) 20000))))
    (def base (string "http://127.0.0.1:" port))
    (def server
      (http/server (fn [req]
                     (if-let [body (tree (req :path))]
                       {:status 200 :headers {"Content-Type" "application/octet-stream"} :body body}
                       {:status 404 :headers {"Content-Type" "text/plain"} :body "not found"}))
                   "127.0.0.1" port))
    (defer (:close server)
      (ev/sleep 0.2)
      (defn update [& flags] (run-copy exe "--self-update" "--base" base "--key" key-file ;flags))
      (defn fails [what [code _ err] needle]
        (assert (and (not= 0 code) (string/find needle err))
                (string what ": exit " code ", stderr " (string/format "%q" err)))
        (assert (unchanged?) (string what ": binary was changed"))
        (assert (not (os/stat (string exe ".new"))) (string what ": temporary file left")))

      (def [ccode cout cerr] (update "--check"))
      (assert (and (= 0 ccode) (string/find "latest  99.0.0" cout)
                   (string/find "update available: yes" cout))
              (string "--check: " ccode " " (string/format "%q" (string cout cerr))))
      (assert (unchanged?) "--check changed the binary")
      (def target (get (peg/match ~(* (thru "target  ") (<- (to "\n"))) cout) 0))
      (assert (index-of target targets) (string "--check target: " target))

      # Between releases the binary is a -dev build; a release build updates freely.
      (when pre-release? (fails "pre-release without --force" (update) "pre-release"))

      (publish :signer other-key)
      (fails "signature by another key" (update "--force") "does not verify")

      (publish)
      (put tree "/latest/download/SHA256SUMS.sig" nil)
      (fails "missing signature" (update "--force") "signature missing")

      (publish)
      (put tree (string "/download/v99.0.0/" (asset "99.0.0" target)) "tampered")
      (fails "hash mismatch" (update "--force") "signed checksum")

      # A replayed older release, correctly signed, must not downgrade.
      (publish :version "0.0.1")
      (def [ocode oout _] (update "--force"))
      (assert (and (= 0 ocode) (string/find "up to date" oout)) (string "older release: " ocode " " oout))
      (assert (unchanged?) "an older release replaced the binary")

      (publish)
      (def [ucode uout uerr] (update "--force"))
      (assert (= 0 ucode) (string "update: " ucode " " (string/format "%q" (string uout uerr))))
      (assert (= (fake-binary target) (string (slurp exe)))
              (string "binary not replaced by the " target " release"))
      (assert (not (os/stat (string exe ".new"))) "temporary file left after update")
      (print "ok self-update " target))))
