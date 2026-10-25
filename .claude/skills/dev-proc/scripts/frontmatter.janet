# Parses the YAML front matter of .work/ documents.
# The block is split off with the same rule as frontmatter.mjs and decoded by the bundled yaml module.
# A value must be a string or a list of strings; an empty value (`owner:`) is an empty list.
#
# A front matter is an ordered array of @[key value] pairs (key order is the emitted order, and a
# decoded mapping has none, so it is recovered from the text); a value is a string or an array of strings.
# Only ASCII whitespace counts as whitespace, where the Node original also trimmed Unicode spaces.
(import yaml)

(defn ws? [c] (or (= c 32) (and (>= c 9) (<= c 13))))

(defn jtrim [s]
  (var a 0)
  (var b (length s))
  (while (and (< a b) (ws? (s a))) (++ a))
  (while (and (> b a) (ws? (s (- b 1)))) (-- b))
  (string/slice s a b))

(defn at? [s pos lit]
  (and (<= (+ pos (length lit)) (length s))
       (= lit (string/slice s pos (+ pos (length lit))))))

(defn fm-get [fm k]
  (when fm (get (find |(= ($ 0) k) fm) 1)))

(defn- sp? [c] (or (= c 32) (= c 9)))

# [fm-start fm-end match-end] for /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/, else nil.
(defn- locate [text]
  (def n (length text))
  (unless (at? text 0 "---") (break nil))
  (var i 3)
  (while (and (< i n) (sp? (text i))) (++ i))
  (when (and (< i n) (= (text i) 13)) (++ i))
  (unless (and (< i n) (= (text i) 10)) (break nil))
  (def start (+ i 1))
  (var p start)
  (var found nil)
  (while (and (not found) (< p n))
    (var j p)
    (when (= (text j) 13) (++ j))
    (when (and (< j n) (= (text j) 10) (at? text (+ j 1) "---"))
      (var k (+ j 4))
      (while (and (< k n) (sp? (text k))) (++ k))
      (cond
        (= k n) (set found [start p k])
        (= (text k) 10) (set found [start p (+ k 1)])
        (and (= (text k) 13) (< (+ k 1) n) (= (text (+ k 1)) 10)) (set found [start p (+ k 2)])))
    (++ p))
  found)

(defn- kind-of [v]
  (cond
    (number? v) "a number"
    (boolean? v) "a boolean"
    (dictionary? v) "a mapping"
    (= v :null) "an empty item"
    (indexed? v) "a nested list"
    (type v)))

# A mapping has no order, so keys are ordered by where they start a line in the text.
(defn- key-order [text known]
  (def seen @{})
  (def out @[])
  (each raw (string/split "\n" text)
    (def line (if (string/has-suffix? "\r" raw) (string/slice raw 0 -2) raw))
    (def c (get line 0))
    (when (and c (not (sp? c)) (not= c 35) (not= c 45))
      (when-let [i (string/find ":" line)]
        (var k (string/slice line 0 i))
        (when (and (>= (length k) 2) (or (= (k 0) 34) (= (k 0) 39)) (= (k 0) (last k)))
          (set k (string/slice k 1 -2)))
        (when (and (known k) (not (seen k)))
          (put seen k true)
          (array/push out k)))))
  (array/concat out (sort (filter |(not (seen $)) (keys known)))))

(defn- decode-fm [text]
  (def [ok v] (protect (yaml/decode text)))
  (unless ok (error (string "invalid front matter: " v)))
  (cond
    (= v :null) @[]
    (not (dictionary? v)) (error "invalid front matter: expected a mapping of keys to strings or lists of strings")
    (do
      (def keys @{})
      (eachk k v
        (unless (string? k) (error (string "invalid front matter: key " (string/format "%q" k) " is not a string")))
        (put keys k true))
      (def out @[])
      (each k (key-order text keys)
        (def val (v k))
        (def parsed
          (cond
            (string? val) val
            (= val :null) @[]
            (and (indexed? val) (all string? val)) (array ;val)
            (error (string "front matter key \"" k "\": expected a string or a list of strings, got "
                           (if (indexed? val) (kind-of (find |(not (string? $)) val)) (kind-of val))))))
        (array/push out @[k parsed]))
      out)))

(defn parse-doc [text]
  (def loc (locate text))
  (unless loc (break {:fm nil :body text}))
  (def [start stop end] loc)
  {:fm (decode-fm (string/slice text start stop)) :body (string/slice text end)})

# Renders one value for writing. Plain text stays plain; a value that would not read back as the
# same string (`a: b`, `# x`, a leading backtick, `true`, `1.5`, ...) is quoted. `list-item?` picks
# the context the value is checked in.
(defn yaml-scalar [v &opt list-item?]
  (def probe (if list-item? (string "k:\n  - " v) (string "k: " v)))
  (def want (if list-item? @{"k" @[v]} @{"k" v}))
  (def [ok got] (protect (yaml/decode probe)))
  (cond
    (and (= v "") (not list-item?)) v
    (and ok (deep= got want)) v
    (find |(or (< $ 32) (= $ 127)) v)
    (string "\"" (string/replace-all "\n" "\\n" (string/replace-all "\r" "\\r" (string/replace-all "\t" "\\t" (string/replace-all "\"" "\\\"" (string/replace-all "\\" "\\\\" v))))) "\"")
    (string "'" (string/replace-all "'" "''" v) "'")))
