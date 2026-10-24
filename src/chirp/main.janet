# chirp: the stock Janet runner with bundled modules, marked as unofficial.

# Evaluated while the image is built; the results are baked into it.
(def- here
  (let [f (dyn *current-file*)]
    (string/slice f 0 (+ 1 (last (string/find-all "/" f))))))
(def- config (parse (slurp (string here "chirp.jdn"))))

# Bindings only: path-bearing keys such as :native and :current-file stay out
# of the image, and the proto chain would drag the whole core env along.
(def- bundled
  (tabseq [name :in (config :modules)
           :let [env (require name)]]
    name (tabseq [[k v] :pairs env :when (symbol? k)] k v)))

# Overlays correct bundled modules without forking them: same-named public
# bindings replace upstream's. Names the module lacks (the overlay's own imports)
# stay out.
(eachp [target overlay] (config :overlays)
  (def into (bundled target))
  (eachp [k v] (require overlay)
    (when (and (symbol? k) (in into k) (not (v :private)))
      (put into k v))))

# Help files and docstrings are read now, in sorted order, and live in the image.
(import ./help)
(def- extra-topics
  (tabseq [[stem path] :pairs (config :help-extra)]
    stem (slurp (string here path))))
(def- help-entries (help/collect (string here "help/") bundled extra-topics))

# The release key is read now, so the binary trusts the key it was built with
# and nothing on the machine it runs on.
(import ./update)
(def- update-config
  {:version (config :version)
   :base ((config :update) :base)
   :targets ((config :update) :targets)
   :key (slurp (string here "release-key.pem"))})

# -h prints this section, so renaming its heading must fail the build.
(def- usage-entry (find |(= "chirp/usage" ($ :id)) help-entries))
(assert usage-entry "help/chirp.md needs a `## Usage` section")

(defn- find-ca []
  (or (os/getenv "SSL_CERT_FILE")
      (when-let [p (find os/stat (config :ca-paths))]
        (os/setenv "SSL_CERT_FILE" p)
        p)))

(defn- identity-line [ca]
  (string "chirp " (config :version) " (unofficial build, not a Janet release)"
          " on Janet " janet/version "-" janet/build
          " - ca: " (or ca "none found")))

# Janet's own run-main is private, so this mirrors it: main runs in a fiber that
# reports errors through the debugger hook, as it does for a script file.
(defn- run-stdin [subargs]
  (def env (make-env))
  (put env *args* subargs)
  (dofile stdin :source "<stdin>" :exit true :env env)
  (when-let [m (module/value env 'main true)]
    (def f (fiber/new (fn [&] (m ;subargs)) :y env))
    (var res nil)
    (while (fiber/can-resume? f)
      (set res (resume f res))
      (when (not= :dead (fiber/status f))
        ((debugger-on-status env) f res)))))

# Janet's list is not copied: its own handler prints it and exits 0.
# Code fences are markdown for `chirp help read`, noise on a terminal.
(defn- print-help []
  (each line (string/split "\n" (string/trim (usage-entry :body)))
    (unless (string/has-prefix? "```" line) (print line)))
  (print)
  (cli-main @["-h"]))

(defn main [& argv]
  (eachp [name env] bundled (put module/cache name env))
  (def ca (find-ca))
  (def args (array/slice argv 1))
  (case (first args)
    # A pipe is not a person: no banner, prompts or echoed values, and failures
    # must show in the exit status.
    nil (if (os/isatty stdin)
          (do
            (print (identity-line ca) " - '(doc)' or 'chirp help' for help")
            (cli-main @["-q"]))
          (run-stdin @["-"]))
    "-" (run-stdin args)
    "-v" (print (identity-line ca))
    "--version" (print (identity-line ca))
    "--changelog" (prin (extra-topics "changelog"))
    "-h" (print-help)
    "--help" (print-help)
    "help" (help/run help-entries (array/slice args 1))
    "self-update" (update/run (array/slice args 1) update-config)
    (cli-main args)))
