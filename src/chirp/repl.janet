### The interactive REPL: Janet's, reading lines with spork/getline.
###
### Stock janet edits lines with a getter from its shell, which a custom
### executable does not link, so cli-main's REPL reads bare lines. This mirrors
### the REPL branch of cli-main (boot.janet) with spork/getline as the getter;
### compare the two when the janet pin moves.

(import spork/getline)
(import spork/rawterm)

(defn- env-var [name]
  (def v (os/getenv name))
  (if (= v "") nil v))

# Names for tab completion: every symbol visible from the REPL's environment.
(defn- completions [env]
  (fn [prefix &]
    (def seen @{})
    (var e env)
    (while e
      (eachk k e
        (when (and (symbol? k) (string/has-prefix? prefix k))
          (put seen k true)))
      (set e (table/getproto e)))
    (sort (keys seen))))

# Ctrl-G shows the docstring of the name before the cursor.
(defn- doc-fetch [env]
  (fn [name w &]
    (when-let [d (get-in env [(symbol name) :doc])]
      (string "\n" (doc-format d w 4)))))

(defn run
  "Run the REPL until end of input."
  []
  (when-let [jp (env-var "JANET_PATH")]
    (def paths (string/split (if (index-of (os/which) [:windows :mingw]) ";" ":") jp))
    (loop [i :down-to [(dec (length paths)) 1]]
      (module/add-syspath (in paths i)))
    (setdyn *syspath* (first paths)))
  (when-let [p (env-var "JANET_PROFILE")] (setdyn *profilepath* p))
  (def color (and (not (env-var "NO_COLOR")) (os/isatty stdout) (os/isatty stderr)))
  (setdyn *pretty-format* (if color "%.20Q" "%.20q"))
  (setdyn *err-color* (if color true))
  (setdyn *doc-color* (if color true))
  (flush)
  (def env (make-env))
  (def getter (getline/make-getline nil (completions env) (doc-fetch env)))
  (defn get-prompt [p]
    (if-let [custom (get env *repl-prompt*)]
      (custom p)
      (string "repl:" ((parser/where p) 0) ":" (parser/state p :delimiters) "> ")))
  (when-let [profile (dyn *profilepath*)]
    (dofile profile :exit true :env env)
    (put env *current-file* nil))
  # The editor fails when the terminal has no room for the prompt, and a fresh
  # pty reports no width at all; there Janet's plain reader takes the line.
  (defn getchunk [buf p]
    (def prompt (get-prompt p))
    (def [_ cols] (rawterm/size))
    (if (> cols (+ (rawterm/monowidth prompt) 8))
      (getter prompt buf)
      (getline prompt buf)))
  (repl getchunk nil env))
