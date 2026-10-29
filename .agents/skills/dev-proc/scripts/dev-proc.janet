#!/usr/bin/env chirp
# dev-proc — the CLI half of the dev-proc skill.
# Mode is never stored separately: it is derived from the .work/ tree on disk.
# Front matter is a restricted YAML subset (scalars, [inline], and "- item" lists).
# Text matching is by hand where the Node original used regexes (Janet has none in core), so
# each helper names the regex it stands for. Paths are POSIX; only ASCII counts as whitespace.
(import ./frontmatter :as fm)
(import ./find)
(import spork/sh)

(def TYPES ["project" "milestone" "wave" "slice" "task"]) # high → low
(def PHASES ["initialize" "execute" "finalize"])
(def RECORDS
  {"decision" {:dir "decisions" :prefix "D" :durable true}
   "learning" {:dir "learnings" :prefix "L" :durable true}
   "backlog" {:dir "backlog" :prefix "B" :durable false}})
(def RECORD-KINDS ["decision" "learning" "backlog"])
(def BASE32 "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567") # RFC 4648
(def HOOK-MARKER "# installed by dev-proc")

(def- b32 ~(+ (range "AZ") (range "27")))
(def- kebab ~(* (+ (range "az") (range "09")) (any (+ (range "az") (range "09") "-"))))
(def- name-peg (peg/compile ~(* ,kebab -1)))
(def- record-id-peg (peg/compile ~(* (<- (set "DLB")) "-" (16 ,b32) -1)))
# Unit ids carry no type, so a rescoped unit keeps its id (and its Work: trailer history).
(def- unit-id-peg (peg/compile ~(* "U-" (16 ,b32) -1)))
(def- unit-dir-peg (peg/compile ~(* (<- (* "U-" (16 ,b32))) "-" (<- ,kebab) -1)))
(def- file-id-peg (peg/compile ~(* (<- (* (set "DLB") "-" (16 ,b32))) (+ "-" (* ".md" -1)))))
# record headings read "# D-… Title"
(def- record-title-peg (peg/compile ~(* (set "DLB") "-" (16 ,b32) (some (set " \t\n\r\v\f")) (<- (any 1)))))

# Path of the running script; templates sit next to the scripts directory.
(def- script-path (do (var p (dyn :current-file))
                      (if (string/has-prefix? "/" p) p (string (os/cwd) "/" p))))

# ---------- errors and output

(defn- die [msg] (error @{:usage msg}))
(defn- strict? [] (= "1" (os/getenv "DEV_PROC_STRICT")))

# JS-style string conversion of a front matter value.
(defn- jstr [v]
  (cond
    (nil? v) "undefined"
    (= v :null) "null"
    (string? v) v
    (indexed? v) (string/join (map jstr v) ",")
    (string v)))

(defn- some-str [s] (when (and s (not= s "")) s))

(defn- today []
  (def d (os/date)) # UTC, as Date#toISOString is
  (string/format "%04d-%02d-%02d" (d :year) (+ 1 (d :month)) (+ 1 (d :month-day))))

(defn- rank [type] (or (index-of type TYPES) -1))
(defn- word? [c] (or (<= 48 c 57) (<= 65 c 90) (<= 97 c 122) (= c 95)))

(defn- todo? [s]
  (and (string/has-prefix? "TODO" s)
       (or (= (length s) 4) (not (word? (s 4))))))

(defn- list-of [v]
  (def items (cond (nil? v) [] (string? v) [v] v))
  (filter |(and (not (empty? $)) (not (todo? $))) items))

# ---------- paths

(defn- normalize [p]
  (def abs? (string/has-prefix? "/" p))
  (def out @[])
  (each seg (string/split "/" p)
    (cond
      (or (= seg "") (= seg ".")) nil
      (= seg "..") (if (and (not (empty? out)) (not= (last out) "..")) (array/pop out) (unless abs? (array/push out "..")))
      (array/push out seg)))
  (def joined (string/join out "/"))
  (if abs? (string "/" joined) (if (empty? joined) "." joined)))

(defn- pjoin [& segs] (normalize (string/join (filter |(not= $ "") segs) "/")))

(defn- resolve [cwd & segs]
  (var acc cwd)
  (each s segs
    (cond (string/has-prefix? "/" s) (set acc s)
          (not= s "") (set acc (string acc "/" s))))
  (normalize acc))

(defn- dirname [p]
  (def i (last (string/find-all "/" p)))
  (if (or (nil? i) (= i 0)) "/" (string/slice p 0 i)))

(defn- basename [p] (last (string/split "/" p)))

# path.relative for normalized absolute paths
(defn- rel [from to]
  (def a (filter |(not= $ "") (string/split "/" from)))
  (def b (filter |(not= $ "") (string/split "/" to)))
  (var i 0)
  (while (and (< i (length a)) (< i (length b)) (= (a i) (b i))) (++ i))
  (string/join [;(map (fn [_] "..") (slice a i)) ;(slice b i)] "/"))

(defn- exists? [p] (not (nil? (os/stat p))))
(defn- dir? [p] (= :directory (os/stat p :mode)))

(defn- mkdirp [p]
  (var acc "")
  (each seg (string/split "/" p)
    (set acc (string acc seg "/"))
    (unless (or (= seg "") (exists? acc)) (os/mkdir acc))))

(defn- read-file [p] (string (slurp p)))

# ---------- git

# Exit code and stdout; stderr is swallowed, as in the Node original.
(defn- run-git [args dir]
  (def res
    (protect
      (let [p (os/spawn ["git" "-C" dir ;args] :p {:out :pipe :err :pipe})
            [o _] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all))
            code (os/proc-wait p)]
        [code (string (or o ""))])))
  (if (res 0) (res 1) [-1 ""]))

(defn- git [args dir]
  (def [code out] (run-git args dir))
  (unless (= code 0) (error (string "git " (string/join args " ") " failed")))
  out)

(defn- try-git [args dir]
  (def [code out] (run-git args dir))
  (if (= code 0) out ""))

(defn- repo-top [cwd]
  (def [code out] (run-git ["rev-parse" "--show-toplevel"] cwd))
  (if (= code 0) (fm/jtrim out) (die "not inside a git repository")))

# ---------- front matter

(defn- fm-set [front k v]
  (def out (array/slice (or front @[])))
  (if-let [i (find-index |(= ($ 0) k) out)]
    (put out i @[k v])
    (array/push out @[k v]))
  out)

(defn- dump-doc [front body]
  (def out @[])
  (each p front
    (def [k v] p)
    (cond
      (nil? v) nil
      (indexed? v) (do (array/push out (string k ":"))
                       (each i v (array/push out (string "  - " (fm/yaml-scalar i true)))))
      (array/push out (string k ": " (fm/yaml-scalar v)))))
  (string "---\n" (string/join out "\n") "\n---\n" body))

(defn- template [name vars]
  (def text (read-file (pjoin (dirname script-path) ".." "templates" name)))
  (def n (length text))
  (def out @"")
  (var i 0)
  (while (< i n)
    (var j (+ i 2))
    (if (fm/at? text i "{{")
      (do
        (while (and (< j n) (word? (text j))) (++ j))
        (if (and (> j (+ i 2)) (fm/at? text j "}}"))
          (do (buffer/push out (get vars (string/slice text (+ i 2) j) "")) (set i (+ j 2)))
          (do (buffer/push-byte out (text i)) (++ i))))
      (do (buffer/push-byte out (text i)) (++ i))))
  (string out))

# String.prototype.replace(string, string): `$$ $& $\` $'` are substitution patterns.
(defn- replace-first [text pat repl]
  (def idx (string/find pat text))
  (if (nil? idx)
    text
    (let [before (string/slice text 0 idx)
          after (string/slice text (+ idx (length pat)))
          out @""
          n (length repl)]
      (var k 0)
      (while (< k n)
        (def c (repl k))
        (def d (when (< (+ k 1) n) (repl (+ k 1))))
        (cond
          (and (= c 36) (= d 36)) (do (buffer/push out "$") (+= k 2))
          (and (= c 36) (= d 38)) (do (buffer/push out pat) (+= k 2))
          (and (= c 36) (= d 96)) (do (buffer/push out before) (+= k 2))
          (and (= c 36) (= d 39)) (do (buffer/push out after) (+= k 2))
          (do (buffer/push-byte out c) (++ k))))
      (string before out after))))

# ---------- multiline-regex stand-ins

(defn- line-start? [s i]
  (or (= i 0) (let [c (s (- i 1))] (or (= c 10) (= c 13)))))

(defn- eol [s i]
  (var e i)
  (while (and (< e (length s)) (not= (s e) 10) (not= (s e) 13)) (++ e))
  e)

(defn- skip-ws [s i]
  (var j i)
  (while (and (< j (length s)) (fm/ws? (s j))) (++ j))
  j)

# /^#\s+(.*)$/m : [start end title] of the first match
(defn- heading-match [body]
  (def n (length body))
  (var res nil)
  (var i 0)
  (while (and (not res) (< i n))
    (when (and (line-start? body i) (= (body i) 35))
      (def j (skip-ws body (+ i 1)))
      (when (> j (+ i 1))
        (def e (eol body j))
        (set res [i e (fm/jtrim (string/slice body j e))])))
    (++ i))
  res)

(defn- title-of [body] (if-let [m (heading-match body)] (m 2) ""))

# /^## <heading>\s*$([\s\S]*?)(?=^## |(?![\s\S]))/m : the section text after the heading line
(defn- section [body heading]
  (def n (length body))
  (def head (string "## " heading))
  (var res nil)
  (var i 0)
  (while (and (not res) (< i n))
    (when (and (line-start? body i) (fm/at? body i head))
      (def k (+ i (length head)))
      (def r (skip-ws body k))
      # \s* is greedy, but `$` must hold where it stops: end of text or before a line break
      (var p r)
      (while (and (>= p k) (not (or (= p n) (= (body p) 10) (= (body p) 13)))) (-- p))
      (when (>= p k)
        (var q p)
        (while (and (< q n) (not (and (line-start? body q) (fm/at? body q "## ")))) (++ q))
        (set res (string/slice body p q))))
    (++ i))
  (or res ""))

# An occurrence at j is a /^\s*<lit>/m match when only whitespace lies between it and a line start.
(defn- at-line-start-ws? [s j]
  (var k j)
  (var nl false)
  (while (and (> k 0) (fm/ws? (s (- k 1))))
    (-- k)
    (when (or (= (s k) 10) (= (s k) 13)) (set nl true)))
  (or (= k 0) nl))

(defn- count-open-items [text]
  # drop /<!--[\s\S]*?-->/ comments; an unclosed one stays
  (def clean @"")
  (var i 0)
  (while (< i (length text))
    (def open (string/find "<!--" text i))
    (def close (when open (string/find "-->" text (+ open 4))))
    (if close
      (do (buffer/push clean (string/slice text i open)) (set i (+ close 3)))
      (do (buffer/push clean (string/slice text i)) (set i (length text)))))
  (def s (string clean))
  (length (filter |(at-line-start-ws? s $) (string/find-all "- [ ]" s))))

(defn- fence? [s]
  (some |(at-line-start-ws? s $) (array/concat (string/find-all "```" s) (string/find-all "~~~" s))))

(defn- numbered-line [s j d]
  (def n (length s))
  (when (and (< (+ j 2) n) (= (s j) (+ 48 d)) (or (= (s (+ j 1)) 46) (= (s (+ j 1)) 41)) (= (s (+ j 2)) 32))
    (def e (eol s (+ j 3)))
    (when (and (< e n) (= (s e) 10)) (+ e 1))))

# /^\s*1[.)] .*\n\s*2[.)] .*\n\s*3[.)] /m
(defn- steps? [s]
  (def n (length s))
  (var hit false)
  (var i 0)
  (while (and (not hit) (< i n))
    (when (line-start? s i)
      (when-let [a (numbered-line s (skip-ws s i) 1)
                 b (numbered-line s (skip-ws s a) 2)]
        (def k (skip-ws s b))
        (when (and (< (+ k 2) n) (= (s k) 51) (or (= (s (+ k 1)) 46) (= (s (+ k 1)) 41)) (= (s (+ k 2)) 32))
          (set hit true))))
    (++ i))
  hit)

(defn- todo-line? [s]
  (var hit false)
  (each i (string/find-all "TODO" s)
    (when (and (line-start? s i) (or (= (+ i 4) (length s)) (not (word? (s (+ i 4))))))
      (set hit true)))
  hit)

# /^#.*$/gm removed
(defn- strip-comments [s]
  (def out @"")
  (var i 0)
  (while (< i (length s))
    (if (and (line-start? s i) (= (s i) 35))
      (set i (eol s i))
      (do (buffer/push-byte out (s i)) (++ i))))
  (string out))

# /^Work:\s*(\S+)\s*$/gm : the captured ids
(defn- work-trailers [s]
  (def n (length s))
  (def out @[])
  (var i 0)
  (while (< i n)
    (var next (+ i 1))
    (when (and (line-start? s i) (fm/at? s i "Work:"))
      (def w1 (skip-ws s (+ i 5)))
      (when (< w1 n)
        (var e1 w1)
        (while (and (< e1 n) (not (fm/ws? (s e1)))) (++ e1))
        (def w2 (skip-ws s e1))
        (var p w2)
        (while (and (>= p e1) (not (or (= p n) (= (s p) 10) (= (s p) 13)))) (-- p))
        (when (>= p e1)
          (array/push out (string/slice s w1 e1))
          (set next (max p (+ i 1))))))
    (set i next))
  out)

# /^(#{2,}) /gm → '#$1 '
(defn- demote-headings [s]
  (def out @"")
  (var i 0)
  (while (< i (length s))
    (when (and (line-start? s i) (= (s i) 35))
      (var k i)
      (while (and (< k (length s)) (= (s k) 35)) (++ k))
      (when (and (>= (- k i) 2) (< k (length s)) (= (s k) 32))
        (buffer/push out "#")))
    (buffer/push-byte out (s i))
    (++ i))
  (string out))

# Log is the last section of STATE.md by convention, so appending to the file appends to it.
(defn- append-log [file line]
  (def text (read-file file))
  (var e (length text))
  (while (and (> e 0) (fm/ws? (text (- e 1)))) (-- e))
  (spit file (string (string/slice text 0 e) "\n- " (today) " " line "\n")))

# ---------- model

(defn- load-root [dir]
  (def units @[])
  (each type TYPES
    (def tdir (pjoin dir type))
    (when (exists? tdir)
      (each entry (sort (os/dir tdir))
        (def udir (pjoin tdir entry))
        (when (dir? udir)
          (def state-path (pjoin udir "STATE.md"))
          (def m (peg/match unit-dir-peg entry))
          (def name (if m (m 1) entry))
          (def problems @[])
          (def u @{:id (if m (m 0) entry) :label (string type "/" name) :type type :name name
                   :dir udir :state-path state-path :body "" :problems problems})
          (unless m (array/push problems (string "directory \"" entry "\" must be U-<16 base32 chars>-<kebab-name>")))
          (if (not (exists? state-path))
            (array/push problems "missing STATE.md")
            (let [[ok d] (protect (fm/parse-doc (read-file state-path)))]
              (if ok
                (do (put u :fm (d :fm)) (put u :body (d :body))
                    (unless (d :fm) (array/push problems "STATE.md has no front matter")))
                (array/push problems (string d)))))
          (array/push units u)))))
  (def records @[])
  (each kind RECORD-KINDS
    (def spec (RECORDS kind))
    (def rdir (pjoin dir (spec :dir)))
    (when (exists? rdir)
      (each f (sort (os/dir rdir))
        (when (string/has-suffix? ".md" f)
          (def file (pjoin rdir f))
          (def m (peg/match file-id-peg f))
          (def id (when m (m 0)))
          (def problems @[])
          (def r @{:kind kind :spec spec :file file :id id :body "" :problems problems})
          (when (or (not id) (not= (string/slice id 0 1) (spec :prefix)))
            (array/push problems (string "filename must start with " (spec :prefix) "-<16 base32 chars>-")))
          (let [[ok d] (protect (fm/parse-doc (read-file file)))]
            (if ok
              (do (put r :fm (d :fm)) (put r :body (d :body))
                  (unless (d :fm) (array/push problems "no front matter")))
              (array/push problems (string d))))
          (array/push records r)))))
  @{:dir dir :base (dirname dir) :units units :records records})

(defn- parent-of [u]
  (def p (fm/fm-get (u :fm) "parent"))
  (when (string? p) p))

(defn- children-of [root id] (filter |(= (parent-of $) id) (root :units)))

# Accepts a unit id (U-…) or, as a convenience, its type/name label.
(defn- find-unit [root ref]
  (or (find |(or (= ($ :id) ref) (= ($ :label) ref)) (root :units))
      (die (string "no active unit \"" (jstr ref) "\" in " (root :dir)))))

(defn- show [u] (string (u :id) " " (u :label)))

(defn- find-record [root id]
  (or (when id (find |(= ($ :id) id) (root :records)))
      (die (string "no record \"" (jstr id) "\" in " (root :dir)))))

# Every .work/ root in the repo, honouring .gitignore; includes untracked ones.
(defn- all-roots [top]
  (def seen @{})
  (def roots @[])
  (each f (string/split "\0" (git ["ls-files" "-z" "--cached" "--others" "--exclude-standard"] top))
    (def segs (string/split "/" f))
    (when-let [i (index-of ".work" segs)]
      (def r (pjoin top ;(slice segs 0 (+ i 1))))
      (unless (seen r) (put seen r true) (array/push roots r))))
  (sort (filter exists? roots)))

(defn- nearest-root [cwd top]
  (var d cwd)
  (var res nil)
  (while true
    (when (exists? (pjoin d ".work")) (set res (pjoin d ".work")) (break))
    (when (or (= d top) (= d (dirname d))) (break))
    (set d (dirname d)))
  res)

# 80 random bits, base32 (16 chars, no padding): unique across branches without coordination.
# Used for both units (U-) and records (D-, L-, B-).
(defn- new-ident [prefix]
  (def bytes (os/cryptorand 10))
  (var bits 0)
  (var acc 0)
  (def out @"")
  (each b bytes
    (set acc (bor (blshift acc 8) b))
    (+= bits 8)
    (while (>= bits 5)
      (buffer/push-byte out (BASE32 (band (brshift acc (- bits 5)) 31)))
      (-= bits 5))
    (set acc (band acc 255))) # only the low `bits` (< 5) bits are still needed
  (string prefix "-" out))

(defn- slugify [s]
  (def out @"")
  (var dash false)
  (each c (string/ascii-lower s)
    (if (or (<= 97 c 122) (<= 48 c 57))
      (do (buffer/push-byte out c) (set dash false))
      (unless dash (buffer/push-byte out 45) (set dash true))))
  (var t (string out))
  (while (string/has-prefix? "-" t) (set t (string/slice t 1)))
  (while (string/has-suffix? "-" t) (set t (string/slice t 0 -2)))
  (set t (if (> (length t) 50) (string/slice t 0 50) t))
  (while (string/has-suffix? "-" t) (set t (string/slice t 0 -2)))
  t)

# ---------- JSON, in the exact shape of JSON.stringify(x, null, 2)

(defn- jobj [& kvs] {:obj (partition 2 kvs)})

(defn- jesc [s]
  (def b @"\"")
  (each c s
    (cond
      (= c 34) (buffer/push b "\\\"")
      (= c 92) (buffer/push b "\\\\")
      (= c 8) (buffer/push b "\\b")
      (= c 12) (buffer/push b "\\f")
      (= c 10) (buffer/push b "\\n")
      (= c 13) (buffer/push b "\\r")
      (= c 9) (buffer/push b "\\t")
      (< c 32) (buffer/push b (string/format "\\u%04x" c))
      (buffer/push-byte b c)))
  (buffer/push b "\"")
  (string b))

(defn- jenc [v ind]
  (def inner (string ind "  "))
  (cond
    (or (nil? v) (= v :null)) "null"
    (boolean? v) (string v)
    (number? v) (string v)
    (string? v) (jesc v)
    (and (struct? v) (v :obj))
    (let [pairs (filter |(not (nil? ($ 1))) (v :obj))]
      (if (empty? pairs)
        "{}"
        (string "{\n" (string/join (map (fn [[k x]] (string inner (jesc k) ": " (jenc x inner))) pairs) ",\n") "\n" ind "}")))
    (indexed? v)
    (if (empty? v)
      "[]"
      (string "[\n" (string/join (map |(string inner (jenc $ inner)) v) ",\n") "\n" ind "]"))
    (error "jenc: unsupported value")))

(defn- print-json [v] (print (jenc v "")))

# ---------- gates

(defn- gate-problems [root u to]
  (def front (u :fm))
  (def p @[])
  (when (or (= to "execute") (= to "finalize"))
    (when (empty? (list-of (fm/fm-get front "success_criteria"))) (array/push p "success_criteria is empty"))
    (when (empty? (list-of (fm/fm-get front "owner"))) (array/push p "owner is empty")))
  (when (= to "closed")
    (def phase (fm/fm-get front "phase"))
    (unless (= phase "finalize")
      (array/push p (string "phase is \"" (jstr phase) "\", must be \"finalize\"")))
    (def kids (children-of root (u :id)))
    (unless (empty? kids)
      (array/push p (string "open children: " (string/join (map show kids) ", "))))
    (def open (count-open-items (section (u :body) "Harvest")))
    (when (> open 0)
      (array/push p (string open " unchecked item(s) in ## Harvest — promote or drop them first"))))
  p)

# ---------- commands

(defn- cmd-init [ctx args]
  (def dir (resolve (ctx :cwd) (or (first (args :pos)) ".") ".work"))
  (if (exists? dir)
    (print "exists: " dir)
    (do
      (mkdirp dir)
      (spit (pjoin dir ".gitkeep") "")
      (print "created " (rel (ctx :top) dir) "/"))))

(defn- unit-line [u]
  (def front (u :fm))
  (def owner (let [o (string/join (list-of (fm/fm-get front "owner")) ", ")] (if (empty? o) "—" o)))
  (def warn (if (empty? (u :problems)) "" (string "  ⚠ " (string/join (u :problems) "; "))))
  (string (show u) "  [" (jstr (or (fm/fm-get front "phase") "?")) "]  owner: " owner warn))

(defn- status-one [ctx root u args]
  (def front (u :fm))
  (def phase (fm/fm-get front "phase"))
  (def next-phase (get {"initialize" "execute" "execute" "finalize" "finalize" "closed"} phase))
  (def parent (parent-of u))
  (def owner (list-of (fm/fm-get front "owner")))
  (def criteria (list-of (fm/fm-get front "success_criteria")))
  (def files (filter |(exists? (pjoin (u :dir) $)) ["DESIGN.md" "PLAN.md" "STATE.md"]))
  (def children (map |(string (show $) " [" (jstr (or (fm/fm-get ($ :fm) "phase") "?")) "]")
                     (children-of root (u :id))))
  (def gate (if next-phase (gate-problems root u next-phase) @[]))
  (if (args "json")
    (print-json (jobj "id" (u :id) "label" (u :label) "mode" (or phase :null) "parent" (or parent :null)
                      "owner" owner "success_criteria" criteria "files" files "children" children
                      "next" next-phase "gate" gate "problems" (u :problems)))
    (do
      (print (show u) "\nmode: " (jstr (or phase :null)))
      (when parent
        (print "parent: " (or (get (find |(= ($ :id) parent) (root :units)) :label) "?") " " parent))
      (print "owner: " (let [o (string/join owner ", ")] (if (empty? o) "—" o)))
      (print "files: " (string/join files ", "))
      (print "success criteria:")
      (each c criteria (print "  - " c))
      (unless (empty? children)
        (print "children:\n" (string/join (map |(string "  - " $) children) "\n")))
      (when next-phase
        (print "gate → " next-phase ": "
               (if (empty? gate) "open" (string "\n  ✗ " (string/join gate "\n  ✗ ")))))
      (unless (empty? (u :problems))
        (print "problems:\n  ⚠ " (string/join (u :problems) "\n  ⚠ "))))))

(defn- cmd-status [ctx args]
  (def root ((ctx :root)))
  (when-let [id (first (args :pos))]
    (status-one ctx root (find-unit root id) args)
    (break))
  (def units (root :units))
  (if (args "json")
    (print-json
      (jobj "root" (rel (ctx :top) (root :dir))
            "units" (map (fn [u]
                           (def front (u :fm))
                           (jobj "id" (u :id) "label" (u :label) "phase" (or (fm/fm-get front "phase") :null)
                                 "parent" (or (parent-of u) :null) "owner" (list-of (fm/fm-get front "owner"))
                                 "problems" (u :problems)))
                         units)
            "records" (map |(jobj "id" (or ($ :id) :null) "kind" ($ :kind) "title" (title-of ($ :body))
                                  "read_if" (list-of (fm/fm-get ($ :fm) "read_if")))
                           (root :records))))
    (do
      (print "root: " (let [r (rel (ctx :top) (root :dir))] (if (empty? r) ".work" r)))
      (when (empty? units) (print "mode: idle — no active units (curate the backlog, or `new`)"))
      (def ids (tabseq [u :in units] (u :id) true))
      (defn walk [u depth]
        (print (string/repeat "  " depth) (unit-line u))
        (each c (children-of root (u :id)) (walk c (+ depth 1))))
      (each u (filter |(let [p (parent-of $)] (or (not p) (not (ids p)))) units) (walk u 0))
      (defn n-of [k] (length (filter |(= ($ :kind) k) (root :records))))
      (print "backlog: " (n-of "backlog") "  decisions: " (n-of "decision") "  learnings: " (n-of "learning")
             " (find \"<topic>\" lists the ones to read)"))))

# Resolves a parent reference to its id, checking it sits at a higher level.
(defn- check-parent [root type parent]
  (when (some-str parent)
    (def p (find-unit root parent))
    (when (>= (rank (p :type)) (rank type))
      (die (string "parent " (p :label) " must be a higher level than " type)))
    (p :id)))

(defn- cmd-new [ctx args]
  (def [type name] (args :pos))
  (unless (index-of type TYPES) (die (string "type must be one of: " (string/join TYPES ", "))))
  (unless (peg/match name-peg (or name "")) (die "name must be kebab-case: [a-z0-9-]"))
  (def root ((ctx :root)))
  (def lbl (string type "/" name))
  (when (find |(= ($ :label) lbl) (root :units)) (die (string lbl " already exists")))
  (def parent (check-parent root type (args "parent")))
  (def id (new-ident "U"))

  (var origin "")
  (when (some-str (args "from"))
    (def b (find-record root (args "from")))
    (unless (= (b :kind) "backlog") (die (string (args "from") " is not a backlog item")))
    # Demote the item's headings so they nest under Origin instead of becoming STATE sections.
    (def body (b :body))
    (def detail (demote-headings
                  (fm/jtrim (if-let [m (heading-match body)]
                              (string (string/slice body 0 (m 0)) (string/slice body (m 1)))
                              body))))
    (set origin (string "\n### Origin\nPromoted from backlog: " (title-of body) "\n\n" detail "\n"))
    (sh/rm (b :file)))

  (def dir (pjoin (root :dir) type (string id "-" name)))
  (mkdirp dir)
  (def owner (if (some-str (args "owner"))
               (map fm/jtrim (string/split "," (args "owner")))
               @["TODO: person and/or agent"]))
  (def front @[@["phase" "initialize"] @["parent" parent] @["owner" owner] @["created" (today)]
               @["success_criteria" @["TODO: observable outcome that proves this unit is done"]]])
  (def vars {"id" id "label" lbl "date" (today)})
  (spit (pjoin dir "STATE.md")
        (dump-doc front (replace-first (template "STATE.md" vars) "<!-- origin -->"
                                       (if (empty? (fm/jtrim origin)) "" origin))))
  (def created @["STATE.md"])
  (each f (filter |(not= $ "") (string/split "," (or (args "with") "")))
    (def file (or (get {"design" "DESIGN.md" "plan" "PLAN.md"} (fm/jtrim f)) (die "--with takes design,plan")))
    (spit (pjoin dir file) (template file vars))
    (array/push created file))
  (print "created " id " " lbl ": " (rel (ctx :top) dir) "/ {" (string/join created ", ") "}  mode: initialize")
  (when (some-str (args "from")) (print "consumed backlog " (args "from"))))

(defn- cmd-phase [ctx args]
  (def [id to] (args :pos))
  (unless (index-of to PHASES)
    (die (string "phase must be one of: " (string/join PHASES ", ") " (use `close` to end a unit)")))
  (def root ((ctx :root)))
  (def u (find-unit root id))
  (def from (fm/fm-get (u :fm) "phase"))
  (when (= from to) (print (show u) " already in " to) (break))
  (def forward (> (index-of to PHASES) (or (and (string? from) (index-of from PHASES)) -1)))
  (def problems (if forward (gate-problems root u to) @[]))
  (when (and (not (empty? problems)) (not (args "force")))
    (die (string "gate → " to " closed:\n  ✗ " (string/join problems "\n  ✗ ")
                 "\n(--force to override, and say why in the Log)")))
  (spit (u :state-path) (dump-doc (fm-set (u :fm) "phase" to) (u :body)))
  (append-log (u :state-path)
              (string "phase " (jstr from) " → " to
                      (if (and (args "force") (not (empty? problems))) " (forced)" "")))
  (print (show u) ": " (jstr from) " → " to))

(defn- cmd-rescope [ctx args]
  (def root ((ctx :root)))
  (def u (find-unit root (first (args :pos))))
  (def type (or (args "type") (u :type)))
  (def name (or (args "name") (u :name)))
  (unless (index-of type TYPES) (die (string "type must be one of: " (string/join TYPES ", "))))
  (unless (peg/match name-peg name) (die "name must be kebab-case"))
  (def parent (if (= (args "parent") "none")
                nil
                (check-parent root type (if (nil? (args "parent")) (parent-of u) (args "parent")))))
  (each k (children-of root (u :id))
    (when (<= (rank (k :type)) (rank type))
      (die (string "child " (k :label) " would no longer be below a " type "; rescope it first"))))
  (def lbl (string type "/" name))
  (when (and (not= lbl (u :label)) (find |(= ($ :label) lbl) (root :units)))
    (die (string lbl " already exists")))

  # The id stays put, so children's parent refs and past Work: trailers remain valid.
  (def new-dir (pjoin (root :dir) type (string (u :id) "-" name)))
  (unless (= new-dir (u :dir))
    (mkdirp (dirname new-dir))
    (os/rename (u :dir) new-dir))
  (def state-path (pjoin new-dir "STATE.md"))
  (def body (u :body))
  (def new-body
    (let [i (find |(and (line-start? body $) (fm/at? body $ "# ")) (range (length body)))]
      (if i
        (string (string/slice body 0 i) "# " lbl (string/slice body (eol body i)))
        body)))
  (spit state-path (dump-doc (fm-set (u :fm) "parent" parent) new-body))
  # JS compares undefined (no parent) with null (none stored), so an absent parent always differs.
  (def old-parent (parent-of u))
  (append-log state-path
              (string "rescoped " (u :label) " → " lbl
                      (if (or (nil? parent) (not= parent old-parent))
                        (string " (parent " (or old-parent "none") " → " (or parent "none") ")")
                        "")))
  (print (u :id) ": " (u :label) " → " lbl))

(defn- cmd-close [ctx args]
  (def root ((ctx :root)))
  (def u (find-unit root (first (args :pos))))
  (def problems (gate-problems root u "closed"))
  (when (args "scrap")
    (cond
      (not (some-str (args "decision"))) (array/push problems "scrapping needs --decision D-… recording why")
      (not (find |(and (= ($ :kind) "decision") (= ($ :id) (args "decision"))) (root :records)))
      (array/push problems (string "decision " (args "decision") " not found"))))
  (unless (empty? problems)
    (die (string "cannot close " (show u) ":\n  ✗ " (string/join problems "\n  ✗ "))))
  (sh/rm (u :dir))
  (print "deleted " (rel (ctx :top) (u :dir)) "/ — stage it in the closing commit, e.g.:\n")
  (print "  " (u :type) " " (u :name) ": " (if (args "scrap") "scrap" "finalize") "\n")
  (print "  Work: " (u :id))
  (when (args "scrap") (print "  Decision: " (args "decision"))))

(defn- cmd-record [ctx args]
  (def [kind & words] (args :pos))
  (def spec (or (RECORDS kind) (die (string "kind must be one of: " (string/join RECORD-KINDS ", ")))))
  (def title (let [t (fm/jtrim (string/join (or words []) " "))] (if (empty? t) (die "a title is required") t)))
  (def root ((ctx :root)))
  (def id (new-ident (spec :prefix)))
  (def file (pjoin (root :dir) (spec :dir) (string id "-" (slugify title) ".md")))
  (def read-if (if (not (empty? (or (args "read-if") []))) (args "read-if") @["TODO: when should a future reader load this?"]))
  (def supersedes (filter |(not= $ "") (map fm/jtrim (string/split "," (or (args "supersedes") "")))))
  (def old (map (fn [s]
                  (def r (find-record root s))
                  (unless (= (r :kind) kind) (die (string s " is not a " kind)))
                  r)
                supersedes))
  (def refs (or (args "ref") @[]))
  (def front
    (case kind
      "decision" @[@["status" "accepted"] @["date" (today)] @["read_if" read-if] @["refs" refs]
                   @["supersedes" (unless (empty? supersedes) supersedes)]]
      "learning" @[@["date" (today)] @["read_if" read-if] @["refs" refs]]
      "backlog" @[@["created" (today)]]))
  (mkdirp (dirname file))
  (spit file (dump-doc front (template (string kind ".md") {"id" id "title" title "date" (today)})))
  (each r old (os/rm (r :file)))
  (print "created " (rel (ctx :top) file))
  (unless (empty? old)
    (print "deleted " (string/join (map |($ :id) old) ", ") " — add to the commit message:")
    (each r old (print "  Supersedes: " (r :id)))))

(defn- check-ref [ref base top]
  (def i (string/find "#" ref))
  (def p (if i (string/slice ref 0 i) ref))
  (def sym (if i (string/slice ref (+ i 1)) ""))
  (def abs (if (string/has-prefix? "/" p) (pjoin top p) (pjoin base p)))
  (def st (os/stat abs))
  (cond
    (nil? st) (string "ref " ref ": file not found")
    (empty? sym) nil
    (= (st :mode) :directory) (string "ref " ref ": symbol given for a directory")
    (do
      (def text (read-file abs))
      # split on "::" or "."; empty parts dropped
      (def parts @[])
      (var start 0)
      (var k 0)
      (while (< k (length sym))
        (cond
          (fm/at? sym k "::") (do (array/push parts (string/slice sym start k)) (+= k 2) (set start k))
          (= (sym k) 46) (do (array/push parts (string/slice sym start k)) (++ k) (set start k))
          (++ k)))
      (array/push parts (string/slice sym start))
      (var bad nil)
      (each part (filter |(not= $ "") parts)
        (unless bad
          # (^|[^\w$])part($|[^\w$])
          (def edge? (fn [c] (or (nil? c) (not (or (word? c) (= c 36))))))
          (unless (find |(and (edge? (get text (- $ 1))) (edge? (get text (+ $ (length part)))))
                        (string/find-all part text))
            (set bad (string "ref " ref ": \"" part "\" not found in " p)))))
      bad)))

(defn- staged-files [top]
  (filter |(not= $ "") (string/split "\0" (try-git ["diff" "--cached" "--name-only" "-z"] top))))

# Each staged file belongs to the deepest .work root whose project dir contains it.
(defn- owning-root [roots top file]
  (var best nil)
  (each r roots
    (def base-rel (rel top (r :base)))
    (when (and (or (= base-rel "") (string/has-prefix? (string base-rel "/") file))
               (or (nil? best) (> (length (r :base)) (length (best :base)))))
      (set best r)))
  best)

(defn- cmd-check [ctx args]
  (def roots (map load-root (all-roots (ctx :top))))
  (def errors @[])
  (def warns @[])
  (each root roots
    (def where (rel (ctx :top) (root :dir)))
    (each u (root :units)
      (def at (string where "/" (u :label) " " (u :id)))
      (each p (u :problems) (array/push errors (string at ": " p)))
      (when (u :fm)
        (def phase (fm/fm-get (u :fm) "phase"))
        (unless (and (string? phase) (index-of phase PHASES))
          (array/push errors (string at ": phase \"" (jstr phase) "\" invalid")))
        (def parent (parent-of u))
        (def p (when parent (find |(= ($ :id) parent) (root :units))))
        (cond
          (and parent (not p)) (array/push errors (string at ": parent " parent " does not exist"))
          (and p (>= (rank (p :type)) (rank (u :type))))
          (array/push errors (string at ": parent " (p :label) " is not a higher level")))
        (unless (= phase "initialize")
          (when (empty? (list-of (fm/fm-get (u :fm) "success_criteria")))
            (array/push errors (string at ": success_criteria empty past initialize")))
          (when (empty? (list-of (fm/fm-get (u :fm) "owner")))
            (array/push errors (string at ": owner empty past initialize"))))))
    (def seen @{})
    (each r (root :records)
      (def at (rel (ctx :top) (r :file)))
      (each p (r :problems) (array/push errors (string at ": " p)))
      (when (r :id)
        (when (seen (r :id))
          (array/push errors (string at ": duplicate id " (r :id) " (also " (seen (r :id)) ")")))
        (put seen (r :id) at))
      (when (empty? (title-of (r :body))) (array/push warns (string at ": no \"# title\" heading")))
      (when (and ((r :spec) :durable) (r :fm))
        (when (empty? (list-of (fm/fm-get (r :fm) "read_if")))
          (array/push errors (string at ": read_if is empty")))
        (each ref (list-of (fm/fm-get (r :fm) "refs"))
          (when-let [bad (check-ref ref (root :base) (ctx :top))]
            (array/push errors (string at ": " bad))))
        # Durable docs hold only why + cues; what/how lives in code and drifts if copied here.
        (when (fence? (r :body))
          (array/push warns (string at ": code block in a durable doc — point at code via refs instead")))
        (when (steps? (r :body))
          (array/push warns (string at ": step-by-step list in a durable doc — that is \"how\", which belongs in code")))
        (when (todo-line? (r :body)) (array/push warns (string at ": unfilled TODO"))))))

  (when (args "staged")
    (def staged (staged-files (ctx :top)))
    (each root roots
      (def root-rel (rel (ctx :top) (root :dir)))
      (when (some |(= (fm/fm-get ($ :fm) "phase") "execute") (root :units))
        (def mine (filter |(= (owning-root roots (ctx :top) $) root) staged))
        (def code (some |(not (string/has-prefix? (string root-rel "/") $)) mine))
        (def state (some |(and (string/has-prefix? (string root-rel "/") $) (string/has-suffix? "/STATE.md" $)) mine))
        (when (and code (not state))
          (array/push (if (strict?) errors warns)
                      (string root-rel ": code changed under an executing unit but no STATE.md is staged — keep docs current in every commit"))))))

  (each w warns (print "warn  " w))
  (each e errors (print "error " e))
  (when (and (empty? errors) (empty? warns))
    (print "ok (" (length roots) " root" (if (= (length roots) 1) "" "s") ")"))
  (when (and (not (empty? errors)) (or (not (args "hook")) (strict?))) (put ctx :exit 1)))

(def FIND-HELP
  `usage: find <words…> [--backlog] [--json]

Lists the decisions and learnings (every .work/ root in the repo) whose read_if cues or title
match the words, best first. --backlog also searches backlog items. --json is for agents.`)

(defn- cmd-find [ctx args]
  (when (or (args "help") (index-of "-h" (args :pos))) (print FIND-HELP) (break))
  (def query (fm/jtrim (string/join (args :pos) " ")))
  (when (empty? query) (die FIND-HELP))
  (def kinds @{"decision" true "learning" true})
  (when (args "backlog") (put kinds "backlog" true))
  (def records
    (seq [dir :in (all-roots (ctx :top))
          r :in ((load-root dir) :records)
          :when (and (kinds (r :kind)) (r :id) (r :fm))]
      {:id (r :id) :kind (r :kind) :root (rel (ctx :top) dir)
       :title (let [t (title-of (r :body)) m (peg/match record-title-peg t)]
                (if m (m 0) t))
       :read-if (list-of (fm/fm-get (r :fm) "read_if"))}))
  (def hits (find/find-records records query))
  (cond
    (args "json")
    (print-json (map |(jobj "id" ($ :id) "kind" ($ :kind) "root" ($ :root) "title" ($ :title)
                            "readIf" ($ :read-if) "cues" ($ :cues) "matched" ($ :matched) "score" ($ :score))
                     hits))
    (empty? hits) (print "no decisions or learnings match \"" query "\"")
    (each h hits
      (print (h :id) "  " (h :title))
      (each cue (h :cues) (print "    read if: " cue)))))

(defn- cmd-check-msg [ctx args]
  (def file (or (first (args :pos)) (die "usage: check-msg <commit-msg-file>")))
  (def msg (strip-comments (read-file (resolve (ctx :cwd) file))))
  (def roots (map load-root (all-roots (ctx :top))))
  (def touched @[])
  (each f (staged-files (ctx :top))
    (when-let [r (owning-root roots (ctx :top) f)]
      (unless (find |(= $ r) touched) (array/push touched r))))
  (def active (some |(not (empty? ($ :units))) touched))
  (def trailers (work-trailers msg))
  (def out @[])
  (when (and active (empty? trailers))
    (array/push out "no \"Work: U-…\" trailer, but staged changes fall under active units"))
  (each t trailers
    (unless (peg/match unit-id-peg t)
      (array/push out (string "trailer \"Work: " t "\" is not a unit id (U-<16 base32 chars>)"))))
  (each o out (print (if (strict?) "error" "warn ") " " o))
  (when (and (not (empty? out)) (strict?)) (put ctx :exit 1)))

(defn- cmd-dig [ctx args]
  (def id (or (first (args :pos)) (die "usage: dig <U-… | D-… | L-… | B-…>")))
  (def root ((ctx :root)))
  (def root-rel (rel (ctx :top) (root :dir)))
  (def rec (peg/match record-id-peg id))
  (var pathspec nil)
  (var matches nil)
  (if rec
    (let [spec (find |(= ($ :prefix) (rec 0)) (map |(RECORDS $) RECORD-KINDS))]
      (set pathspec (string root-rel "/" (spec :dir) "/"))
      (set matches (fn [f] (or (string/has-prefix? (string id "-") (basename f)) (= (basename f) (string id ".md"))))))
    (do
      (unless (peg/match unit-id-peg id) (die "dig takes an id (U-…, D-…, L-…, B-…); names are reused, ids are not"))
      (set pathspec (string root-rel "/"))
      # Any type dir: the unit may have been rescoped between commits.
      (set matches (fn [f] (some |(string/has-prefix? (string id "-") $) (string/split "/" f))))))

  (def top (ctx :top))
  (def trail (fm/jtrim (try-git ["log" "--all" "--date=short" "--format=%h %ad %s" "-E"
                                 (string "--grep=^(Work|Supersedes|Decision): " id "$")] top)))
  (unless (empty? trail)
    (print "commits with a trailer for " id ":\n"
           (string/join (map |(string "  " $) (string/split "\n" trail)) "\n") "\n"))

  (def log (try-git ["log" "--all" "--no-renames" "--diff-filter=D" "--format=@@%H %h %ad" "--date=short"
                     "--name-only" "--" pathspec] top))
  (def deletions
    (filter |(not (empty? ($ :files)))
            (seq [block :in (string/split "@@" log) :unless (empty? block)]
              (def [head & files] (string/split "\n" (fm/jtrim block)))
              (def [full short date] (string/split " " head))
              {:full full :short short :date date :files (filter |(and (not= $ "") (matches $)) files)})))
  (when (empty? deletions)
    (when (empty? trail) (die (string "no history found for " id " under " root-rel)))
    (break))
  (def [last-d & older] deletions)
  (print "deleted in " (last-d :short) " (" (last-d :date) "); last version from " (last-d :short) "^:\n")
  (each f (last-d :files)
    (print "===== " f)
    (print (try-git ["show" (string (last-d :full) "^:" f)] top)))
  (unless (empty? older)
    (print "earlier deletions: " (string/join (map |(string ($ :short) " (" ($ :date) ")") older) ", "))))

(defn- cmd-hooks [ctx args]
  (unless (= (first (args :pos)) "install") (die "usage: hooks install"))
  (def top (ctx :top))
  (def hooks-dir (resolve top (fm/jtrim (git ["rev-parse" "--git-path" "hooks"] top))))
  (def script-rel (rel top script-path))
  (def script (if (string/has-prefix? ".." script-rel)
                (jesc script-path)
                (string "\"$(git rev-parse --show-toplevel)/" script-rel "\"")))
  (def guard "command -v chirp >/dev/null 2>&1 || { echo \"dev-proc: chirp not found, skipping checks\" >&2; exit 0; }")
  (def hooks [["pre-commit" (string "exec chirp " script " check --staged --hook")]
              ["commit-msg" (string "exec chirp " script " check-msg \"$1\"")]])
  (mkdirp hooks-dir)
  (def umask (let [m (os/umask 0)] (os/umask m) m))
  (each [name cmd] hooks
    (def file (pjoin hooks-dir name))
    (def existed (exists? file))
    (if (and existed (not (string/find HOOK-MARKER (read-file file))))
      (print "skip  " name ": a foreign hook exists; add this line to it yourself:\n      " (string/slice cmd 5))
      (do
        (spit file (string "#!/bin/sh\n" HOOK-MARKER "\n" guard "\n" cmd "\n"))
        (unless existed (os/chmod file (band 8r755 (bnot umask))))
        (print "wrote " (let [r (rel top file)] (if (empty? r) file r))))))
  (print "hooks warn by default; set DEV_PROC_STRICT=1 to make them block"))

(def HELP
  (string "dev-proc — units (" (string/join TYPES " > ") ") moving " (string/join PHASES " → ") "\n\n"
    `  init [dir]                               create <dir>/.work/
  <unit> is a unit id (U-…) or, for active units, its <type>/<name> label

  status [<unit>] [--json]                 tree of units, or one unit's mode + gate
  find <words…> [--backlog] [--json]       decisions and learnings whose read_if or title match what you are about to do
  new <type> <name> [--parent <unit>] [--owner a,b] [--from B-…] [--with design,plan]
  phase <unit> <phase>      [--force]      move a unit (forward moves are gated)
  rescope <unit> [--type t] [--name n] [--parent <unit>|none]
  close <unit> [--scrap --decision D-…]   delete a finalized unit's docs
  record <decision|learning|backlog> <title> [--read-if "…"]… [--ref path#symbol]… [--supersedes D-…,…]
  check [--staged]                         lint every .work/ root in the repo
  check-msg <file>                         lint a commit message's Work: trailer
  dig <U-…|D-…|L-…|B-…>                    show deleted docs from git history
  hooks install                            pre-commit + commit-msg hooks (DEV_PROC_STRICT=1 blocks)

  --root <dir>   use this .work/ instead of the nearest one above cwd`))

(def COMMANDS
  {"init" cmd-init "status" cmd-status "find" cmd-find "new" cmd-new "phase" cmd-phase
   "rescope" cmd-rescope "close" cmd-close "record" cmd-record "check" cmd-check
   "check-msg" cmd-check-msg "dig" cmd-dig "hooks" cmd-hooks})
(def BOOLEAN {"json" true "scrap" true "staged" true "hook" true "force" true "help" true "backlog" true})
(def REPEATABLE {"read-if" true "ref" true})

# Positional arguments live under :pos; flags under their string name.
(defn- parse-args [argv]
  (def args @{:pos @[]})
  (var i 0)
  (while (< i (length argv))
    (def a (argv i))
    (if (not (string/has-prefix? "--" a))
      (array/push (args :pos) a)
      (let [s (string/slice a 2)
            eq (string/find "=" s)
            key (if eq (string/slice s 0 eq) s)]
        (if (BOOLEAN key)
          (put args key true)
          (do
            (var val (when eq (string/slice s (+ eq 1))))
            (when (nil? val)
              (++ i)
              (when (>= i (length argv)) (die (string "--" key " needs a value")))
              (set val (argv i)))
            (if (REPEATABLE key)
              (do (unless (args key) (put args key @[])) (array/push (args key) val))
              (put args key val))))))
    (++ i))
  args)

(defn- run [argv]
  (def cmd (first argv))
  (when (or (nil? cmd) (= cmd "") (= cmd "help") (= cmd "--help") (= cmd "-h"))
    (print HELP)
    (break 0))
  (def f (or (COMMANDS cmd) (die (string "unknown command \"" cmd "\"\n\n" HELP))))
  (def args (parse-args (slice argv 1)))
  (def cwd (os/cwd))
  (def top (repo-top cwd))
  (def ctx @{:cwd cwd :top top :exit 0})
  (put ctx :root
       (fn []
         (def dir (if (some-str (args "root")) (resolve cwd (args "root")) (nearest-root cwd top)))
         (when (or (not dir) (not (exists? dir)))
           (die "no .work/ found from here up to the repo root — run `dev-proc init`"))
         (load-root dir)))
  (f ctx args)
  (ctx :exit))

(defn main [_ & argv]
  (def code
    (try (run argv)
      ([e]
        (if (and (table? e) (e :usage))
          (do (eprint "dev-proc: " (e :usage)) 2)
          (do (eprint "dev-proc: " (string e)) 1)))))
  (file/flush stdout)
  (unless (= code 0) (os/exit code)))
