# Importing a bundled module by its short name fails with the import that
# works (#8), and so does using one of its functions unimported (#22). A module
# of that name on disk still wins, and a name chirp cannot fix with an import
# keeps Janet's own error.
(import spork/sh)

(def exe (let [e (dyn *executable*) [ok p] (protect (os/realpath e))] (if ok p e)))

(defn- tmpdir [tag]
  (def d (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                 "/chirp-smoke-" tag "-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs d)
  (os/realpath d))

(defn- run
  "Run chirp with argv and env added. Returns [exit-code stdout stderr]."
  [argv &opt env]
  (def p (os/spawn [exe ;argv] :pe (merge (os/environ) (or env {}) {:out :pipe :err :pipe})))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn- run-e [code &opt env] (run ["-e" code] env))

(def- tasks-pointer "chirp --help read tasks")

(defn- assert-hinted [what [code _ err] want]
  (assert (and (not= 0 code) (string/find want err) (string/find tasks-pointer err))
          (string what ": " code " " err)))

(defn- assert-plain-error [what [code _ err] want]
  (assert (and (not= 0 code) (string/find want err) (not (string/find "chirp bundles" err)))
          (string what ": " code " " err)))

(defn- check-import-hints []
  (each [short want] [["json" "(import spork/json :as json)"]
                      ["sh" "(import spork/sh :as sh)"]
                      ["toml" "(import tomlin :as toml)"]
                      ["https" "(import spork-https :as https)"]]
    (assert-hinted (string "import " short) (run-e (string "(import " short ")")) want))
  (assert-plain-error "unknown module" (run-e "(import nosuch-module)")
                      "could not find module nosuch-module:")

  (def tmp (tmpdir "import-hint"))
  (defer (sh/rm tmp)
    (spit (string tmp "/json.janet") "(def x 42)")
    (def [code out err] (run-e "(import json) (prin json/x)" {"JANET_PATH" tmp}))
    (assert (and (= 0 code) (= "42" out)) (string "json.janet on disk: " code " " out err))))

(defn- check-symbol-hints []
  (def want "(import jsec/crypto :as crypto)")
  (def call "(print (crypto/digest :sha256 \"x\"))")
  (def tmp (tmpdir "symbol-hint"))
  (defer (sh/rm tmp)
    (assert-hinted "crypto/digest via -e" (run-e call) want)

    (spit (string tmp "/call.janet") call)
    (assert-hinted "crypto/digest via script" (run [(string tmp "/call.janet")]) want)

    # A module's own environment gets the hint too.
    (spit (string tmp "/mod.janet") "(json/encode 1)")
    (spit (string tmp "/main.janet") "(import ./mod)")
    (assert-hinted "json/encode in a module" (run [(string tmp "/main.janet")])
                   "(import spork/json :as json)"))

  # No import fixes these: core's math/floor is meant, or the module has no such name.
  (assert-plain-error "math/flor" (run-e "(math/flor 1.5)") "unknown symbol math/flor")
  (assert-plain-error "crypto/nonexistent" (run-e "(crypto/nonexistent 1)")
                      "unknown symbol crypto/nonexistent")
  (assert-plain-error "unknown prefix" (run-e "(nosuch/x 1)") "unknown symbol nosuch/x")

  (def [code out err] (run-e "(import jsec/crypto :as crypto) (crypto/digest :sha256 \"x\")"))
  (assert (= 0 code) (string "imported crypto/digest: " code " " out err)))

(defn main [&]
  (check-import-hints)
  (check-symbol-hints)
  (print "ok import-hint"))
