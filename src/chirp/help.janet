# Offline help. collect runs while the image is built and its result is baked in;
# run searches it at runtime with an in-memory FTS5 index, so nothing is read
# from disk and no database blob ships.
(import sqlite3)
(import ./help-serve)

(defn- slug [s]
  (string/join (peg/match ~(any (+ (<- (some (range "az" "09"))) 1))
                          (string/ascii-lower s)) "-"))

# Lines before the first `##`, then one array of lines per `##` section. A
# `##` inside a code fence is code, not a heading.
(defn- split-sections [text]
  (def pre @[])
  (def sections @[])
  (var cur pre)
  (var fence false)
  (each line (string/split "\n" text)
    (when (string/has-prefix? "```" line) (set fence (not fence)))
    (if (and (not fence) (string/has-prefix? "## " line))
      (array/push sections (set cur @[line]))
      (array/push cur line)))
  [pre sections])

(defn- md-entries [stem text]
  (def [pre sections] (split-sections text))
  (def h1 (find |(string/has-prefix? "# " $) pre))
  (def entries
    @[{:id stem :kind :topic :text (string/trim text)
       :title (if h1 (string/trim (string/slice h1 2)) stem)
       :body (string/join pre "\n")}])
  (each [heading & lines] sections
    (def title (string/trim (string/slice heading 3)))
    (array/push entries
                {:id (string stem "/" (slug title)) :kind :section :title title
                 :text (string/trim (string/join [heading ;lines] "\n"))
                 :body (string/join lines "\n")}))
  entries)

(defn collect
  "Sorted help entries: the .md files in dir and the extra topics (a table of
  stem -> markdown text), where stem = topic id and each `##` is a section,
  plus the documented public bindings of the modules table and of Janet's core."
  [dir modules extra]
  (def out @[])
  (def seen @{})
  (defn add [e]
    (assert (not (seen (e :id))) (string "duplicate help id " (e :id)))
    (put seen (e :id) true)
    (array/push out e))
  (defn add-topic [stem text]
    (assert (not (in modules stem)) (string "help topic " stem " shadows a bundled module"))
    (each e (md-entries stem text) (add e)))
  (each file (sorted (os/dir dir))
    (when (string/has-suffix? ".md" file)
      (add-topic (string/slice file 0 -4) (slurp (string dir file)))))
  (each stem (sorted (keys extra)) (add-topic stem (extra stem)))
  # Imports show up in a module's env as `prefix/name` and belong to another
  # module; core's own names legitimately contain a slash.
  (defn add-docs [prefix env imports?]
    (eachp [k b] env
      (when (and (symbol? k) (table? b) (string? (b :doc)) (not (b :private))
                 (or (not imports?) (not (string/find "/" k))))
        (add {:id (string prefix k) :kind :doc :text (b :doc)
              :title (first (string/split "\n" (b :doc))) :body (b :doc)}))))
  (each name (sorted (keys modules)) (add-docs (string name "/") (modules name) true))
  (add-docs "" root-env false)
  (sort-by |($ :id) out))

(defn- die [& msg] (eprint "chirp --help: " ;msg) (os/exit 1))

(defn print-topics
  "Print the help topics, one per line: id and title."
  [entries]
  (print "Topics\n")
  (each e entries
    (when (= :topic (e :kind)) (print "  " (e :id) "  " (e :title)))))

(defn- one-line [s] (string/trim (peg/replace-all ~(some (set " \t\r\n")) " " s)))

(defn index
  "An open in-memory FTS5 database over the entries. The caller closes it."
  [entries]
  (def db (sqlite3/open ":memory:"))
  # The porter stemmer lets `certificate` find `certificates`.
  (sqlite3/eval db "CREATE VIRTUAL TABLE t USING fts5(id, title, body, tokenize = 'porter unicode61');")
  (sqlite3/eval db "BEGIN;")
  (each e entries
    (sqlite3/eval db "INSERT INTO t VALUES (?, ?, ?);" [(e :id) (e :title) (e :body)]))
  (sqlite3/eval db "COMMIT;")
  db)

(defn search
  "Ranked hits for an FTS5 query: [true rows] with id, title and snippet `s`, or
  [false message] when the query is invalid."
  [db q limit]
  # Title outweighs id outweighs body.
  (protect (sqlite3/eval db (string/format
                              "SELECT id, title, snippet(t, 2, '', '', '...', 16) AS s FROM t
                               WHERE t MATCH :q ORDER BY bm25(t, 3.0, 10.0, 1.0) LIMIT %d;" limit)
                         {:q q})))

(defn- cmd-query [entries args]
  (var limit 10)
  (def words @[])
  (var i 0)
  (while (< i (length args))
    (def a (args i))
    (if (= a "--limit")
      (do (++ i)
          (set limit (scan-number (get args i "")))
          (unless (and (int? limit) (pos? limit)) (die "--limit needs a positive integer")))
      (array/push words a))
    (++ i))
  (when (empty? words) (die "query needs a search string, e.g. chirp --help query certificate"))
  (def db (index entries))
  (def [ok rows] (defer (sqlite3/close db) (search db (string/join words " ") limit)))
  (unless ok (die "invalid query: " rows))
  (if (empty? rows)
    (print "no matches")
    (each {:id id :title title :s s} rows
      (print id "  " title)
      (print "    " (one-line s)))))

(defn- cmd-read [entries args]
  (unless (= 1 (length args)) (die "read needs exactly one id, e.g. chirp --help read https"))
  (def id (first args))
  (if-let [e (find |(= id ($ :id)) entries)]
    (print (e :text))
    (let [near (take 5 (filter |(string/find id ($ :id)) entries))]
      (die "no entry " id
           (if (empty? near) ". Try: chirp --help query <words>"
             (string ". Did you mean: " (string/join (map |($ :id) near) ", ")))))))

(defn- cmd-serve [entries args serve-config]
  (var port (serve-config :port))
  (var host (serve-config :host))
  (var i 0)
  (while (< i (length args))
    (def a (args i))
    (case a
      "--port" (do
                 (++ i)
                 (set port (scan-number (get args i "")))
                 (unless (and (int? port) (<= 1 port 65535))
                   (eprint "chirp --help: serve: --port needs an integer from 1 to 65535")
                   (os/exit 2)))
      "--host" (do
                 (++ i)
                 (set host (get args i))
                 (when (or (nil? host) (empty? host))
                   (eprint "chirp --help: serve: --host needs an address, e.g. 0.0.0.0")
                   (os/exit 2)))
      (do (eprint "chirp --help: serve: unknown option " a ". Try: chirp --help read help")
          (os/exit 2)))
    (++ i))
  # One index for the server's whole life; every request searches it.
  (def db (index entries))
  (help-serve/serve entries (fn [q limit] (search db q limit))
                    (merge serve-config {:port port :host host})))

(defn run
  "Dispatch `chirp --help <word> ...`; args are the words after `--help`, at
  least one. An unknown word is a usage error: exit 2. serve-config is what
  `serve` needs: :host, :port, :style (stylesheet text) and :version."
  [entries args serve-config]
  (case (first args)
    "query" (cmd-query entries (slice args 1))
    "read" (cmd-read entries (slice args 1))
    "serve" (cmd-serve entries (slice args 1) serve-config)
    (do (eprint "chirp --help: unknown command " (first args)
                ". Try: chirp -h")
        (os/exit 2))))
