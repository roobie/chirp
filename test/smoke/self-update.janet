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

      # --output saves the release elsewhere and never touches the running binary.
      (publish)
      (def want (fake-binary target))
      (def out-dir (string tmp "/out"))
      (os/mkdir out-dir)
      (def [dcode dout derr] (update "--output" out-dir))
      (def in-dir (string out-dir "/" (asset "99.0.0" target)))
      (assert (and (= 0 dcode) (string/find in-dir dout) (= want (string (slurp in-dir))))
              (string "--output DIR: " dcode " " (string/format "%q" (string dout derr))))
      (def out-file (string tmp "/chirp-saved"))
      (def [fcode fout ferr] (update "--output" out-file))
      (assert (and (= 0 fcode) (= want (string (slurp out-file))))
              (string "--output FILE: " fcode " " (string/format "%q" (string fout ferr))))
      (assert (unchanged?) "--output changed the running binary")

      # A binary its owner may write, in a directory nobody but root may: the
      # update cannot rename, so it saves the verified release and says how to
      # install it. Root and windows ignore the mode, so there it cannot be tested.
      (def ro (string tmp "/ro"))
      (os/mkdir ro)
      (def ro-exe (string ro "/chirp-copy" (if windows? ".exe" "")))
      (spit ro-exe original)
      (unless windows? (os/chmod ro-exe 8r755))
      (os/chmod ro 8r555)
      (defer (os/chmod ro 8r755)
        (def probe (string ro "/probe"))
        (if (when-let [f (file/open probe :wb)] (file/close f) (os/rm probe) true)
          (print "skip self-update read-only directory: this user can write to any directory")
          (do
            (def [rcode rout rerr]
              (run-copy ro-exe "--self-update" "--force" "--base" base "--key" key-file))
            (def saved (get (peg/match ~(* (thru "saved at ") (<- (to ";"))) rerr) 0))
            (assert (and (not= 0 rcode) (string/find "is not writable" rerr) saved
                         (string/find (string " " saved " ") rerr))
                    (string "read-only directory: " rcode " " (string/format "%q" (string rout rerr))))
            (defer (sh/rm (string/slice saved 0 (last (string/find-all "/" saved))))
              (assert (= want (string (slurp saved))) "read-only directory: saved file is not the release"))
            (assert (= original (string (slurp ro-exe))) "read-only directory: binary was changed")
            (assert (not (os/stat (string ro-exe ".new"))) "read-only directory: temporary file left"))))

      (def [ucode uout uerr] (update "--force"))
      (assert (= 0 ucode) (string "update: " ucode " " (string/format "%q" (string uout uerr))))
      (assert (= (fake-binary target) (string (slurp exe)))
              (string "binary not replaced by the " target " release"))
      (assert (not (os/stat (string exe ".new"))) "temporary file left after update")
      (print "ok self-update " target))))
