# chirp's own commands are `--` flags, so bare words are always script files:
# scripts named like the old subcommands run like any other.
(import spork/sh)

# run changes directory, so a relative path to the binary would stop working.
(def exe
  (let [e (dyn *executable*)
        [ok p] (protect (os/realpath e))]
    (if ok p (string (os/cwd) "/" e))))

(defn- run-in [dir & args]
  (def before (os/cwd))
  (os/cd dir)
  (defer (os/cd before)
    (def p (os/spawn [exe ;args] :p {:out :pipe :err :pipe}))
    (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
    [(os/proc-wait p)
     (string/replace-all "\r" "" (string out))
     (string/replace-all "\r" "" (string err))]))

(defn main [&]
  (def tmp (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                   "/chirp-smoke-script-names-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs tmp)
  (defer (sh/rm tmp)
    (each name ["help" "self-update"]
      (spit (string tmp "/" name)
            (string "(defn main [& args] (print \"ran " name ":\" (string/join (slice args 1) \",\")))\n")))
    (def [hcode hout herr] (run-in tmp "help" "x"))
    (assert (and (= 0 hcode) (string/find "ran help:x" hout)) (string "help script: " hout herr))
    (def [ucode uout uerr] (run-in tmp "self-update" "y"))
    (assert (and (= 0 ucode) (string/find "ran self-update:y" uout)) (string "self-update script: " uout uerr)))
  (print "ok script-names"))
