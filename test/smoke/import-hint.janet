# Importing a bundled module by its short name fails with the import that
# works (#8); a module of that name on disk still wins, and an unknown name
# keeps Janet's own error.
(import spork/sh)

(def exe (let [e (dyn *executable*) [ok p] (protect (os/realpath e))] (if ok p e)))

(defn- tmpdir [tag]
  (def d (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                 "/chirp-smoke-" tag "-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs d)
  (os/realpath d))

(defn- run-e
  "Run chirp -e code with env added. Returns [exit-code stdout stderr]."
  [code &opt env]
  (def p (os/spawn [exe "-e" code] :pe (merge (os/environ) (or env {}) {:out :pipe :err :pipe})))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn main [&]
  (each [short want] [["json" "(import spork/json :as json)"]
                      ["sh" "(import spork/sh :as sh)"]
                      ["toml" "(import tomlin :as toml)"]
                      ["https" "(import spork-https :as https)"]]
    (def [code _ err] (run-e (string "(import " short ")")))
    (assert (and (not= 0 code) (string/find want err) (string/find "chirp --help read tasks" err))
            (string "import " short ": " code " " err)))

  (def [ucode _ uerr] (run-e "(import nosuch-module)"))
  (assert (and (not= 0 ucode) (string/find "could not find module nosuch-module:" uerr)
               (not (string/find "chirp bundles" uerr)))
          (string "unknown module: " uerr))

  (def tmp (tmpdir "import-hint"))
  (defer (sh/rm tmp)
    (spit (string tmp "/json.janet") "(def x 42)")
    (def [dcode dout derr] (run-e "(import json) (prin json/x)" {"JANET_PATH" tmp}))
    (assert (and (= 0 dcode) (= "42" dout)) (string "json.janet on disk: " dcode " " dout derr)))
  (print "ok import-hint"))
