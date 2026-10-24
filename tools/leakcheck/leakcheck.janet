# Keeps host-specific details (local paths, account names, local secrets)
# out of the public repo. Generic rules live in rules.jdn, exemptions in
# allow.jdn; values describing this host are read at runtime, never stored.

(def- dir "tools/leakcheck/")

(defn- run
  "Run a command; return [exit-code stdout]."
  [& args]
  (def p (os/spawn args :p {:out :pipe}))
  (def out (or (ev/read (p :out) :all) @""))
  [(os/proc-wait p) (string out)])

(defn- git [& args]
  (def [code out] (run "git" ;args))
  (unless (zero? code) (error (string "git " (string/join args " ") " failed")))
  out)

(defn- bounded
  "PEG source matching s only where it is not part of a longer word."
  [s]
  ~(* (! (> -1 (+ :w (set "-_")))) ,s (! (+ :w (set "-_")))))

(defn- spans
  "Compile src into a PEG returning [start end] of every non-overlapping match."
  [src]
  (peg/compile ~(any (+ (/ (* ($) (drop ,src) ($)) ,tuple) 1))))

(defn build-needles
  "Everything to search for: the generic rules plus this host's own values."
  [rules env hostname]
  (def needles @[])
  (def seen @{})
  (defn add [rule src &opt secret]
    (def key [rule src])
    (unless (seen key)
      (put seen key true)
      (array/push needles {:rule rule :peg (spans src) :secret (truthy? secret)})))
  (each r (rules :rules) (add (r :name) (r :peg)))
  (when-let [home (env "HOME")]
    (when (> (length home) 1) (add "host-home" (bounded home))))
  (each var ["USER" "LOGNAME" "USERNAME"]
    (when-let [u (env var)]
      (when (>= (length u) 3) (add "host-user" (bounded u)))))
  (when hostname
    (def short (first (string/split "." hostname)))
    (each h [hostname short]
      (when (>= (length h) 3) (add "host-name" (bounded h)))))
  (def secret-name (peg/compile (rules :secret-env-name)))
  (def min-len (rules :min-secret-length))
  (eachp [k v] env
    (when (peg/find secret-name k)
      (add "env-secret-name" (bounded k))
      (when (>= (length v) min-len) (add "env-secret-value" v true))))
  needles)

(defn scan-text
  "Findings in text as {:line :rule :text :secret}. Binary text is skipped."
  [text needles]
  (def found @[])
  (unless (string/find "\0" text)
    (var n 0)
    (each line (string/split "\n" text)
      (++ n)
      (each nd needles
        (each [s e] (peg/match (nd :peg) line)
          (array/push found {:line n :rule (nd :rule)
                             :text (string/slice line s e)
                             :secret (nd :secret)})))))
  found)

(defn- path-match? [pattern path]
  (if (string/has-suffix? "/" pattern)
    (string/has-prefix? pattern path)
    (= pattern path)))

(defn allowed?
  "True when an exemption covers finding f in path. Every key an entry sets must match."
  [allow path f]
  (truthy?
    (find (fn [a]
            (and (or (nil? (a :path)) (path-match? (a :path) path))
                 (or (nil? (a :rule)) (= (a :rule) (f :rule)))
                 (or (nil? (a :text)) (= (a :text) (f :text)))))
          allow)))

(defn- hostname []
  (try
    (let [[code out] (run "hostname")]
      (when (zero? code) (string/trim out)))
    ([_] nil)))

(defn- load-jdn [top name]
  (parse (slurp (string top "/" dir name))))

(defn- commit-msg-text
  "Message as git will store it: comment lines blanked so line numbers still match."
  [file]
  (string/join
    (map |(if (string/has-prefix? "#" $) "" $) (string/split "\n" (slurp file)))
    "\n"))

(defn- usage []
  (eprint "usage: leakcheck.janet staged | all | msg <commit-msg-file>")
  (os/exit 2))

(defn main [_ &opt mode arg]
  (def top (string/trim (git "rev-parse" "--show-toplevel")))
  (def needles (build-needles (load-jdn top "rules.jdn") (os/environ) (hostname)))
  # allow.jdn has to quote the text it exempts. That is fine for the generic
  # rules, but never for this host's own values.
  (def allow
    (let [entries (load-jdn top "allow.jdn")
          generic (map |($ :name) ((load-jdn top "rules.jdn") :rules))]
      [;entries
       ;(seq [a :in entries :when (a :text) r :in generic]
          {:path (string dir "allow.jdn") :rule r :text (a :text)})]))
  (def targets
    (case mode
      "staged" (map |[$ (git "show" (string ":" $))]
                    (filter |(not (empty? $))
                            (string/split "\0" (git "diff" "--cached" "--name-only"
                                                    "--diff-filter=ACMR" "-z"))))
      "all" (map |[$ (git "show" (string ":" $))]
                 (filter |(not (empty? $)) (string/split "\0" (git "ls-files" "-z"))))
      "msg" (if arg [["COMMIT_MSG" (commit-msg-text arg)]] (usage))
      (usage)))
  (var bad 0)
  (each [path text] targets
    (each f (scan-text text needles)
      (unless (allowed? allow path f)
        (++ bad)
        (eprintf "%s:%d: %s: %s" path (f :line) (f :rule)
                 (if (f :secret) "<redacted>" (f :text))))))
  (when (pos? bad)
    (eprintf "leakcheck: %d host-specific finding(s). Remove them, or add an exemption to %sallow.jdn." bad dir)
    (os/exit 1)))
