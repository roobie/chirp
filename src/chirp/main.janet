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
(def- help-entries (help/collect (string here "help/") bundled))

(defn- find-ca []
  (or (os/getenv "SSL_CERT_FILE")
      (when-let [p (find os/stat (config :ca-paths))]
        (os/setenv "SSL_CERT_FILE" p)
        p)))

(defn- identity-line [ca]
  (string "chirp " (config :version) " (unofficial build, not a Janet release)"
          " on Janet " janet/version "-" janet/build
          " - ca: " (or ca "none found")))

(defn main [& argv]
  (eachp [name env] bundled (put module/cache name env))
  (def ca (find-ca))
  (def args (array/slice argv 1))
  (case (first args)
    nil (do
          (print (identity-line ca) " - '(doc)' for help")
          (cli-main @["-q"]))
    "-v" (print (identity-line ca))
    "--version" (print (identity-line ca))
    "help" (help/run help-entries (array/slice args 1))
    (cli-main args)))
