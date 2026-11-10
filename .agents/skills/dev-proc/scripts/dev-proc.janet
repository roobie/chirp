#!/usr/bin/env chirp
# dev-proc — the CLI half of the dev-proc skill.
# Mode is never stored separately: it is derived from the .work/ tree on disk.
# Front matter is a restricted YAML subset (scalars, [inline], and "- item" lists).
# Text matching is by hand where the Node original used regexes (Janet has none in core), so
# each helper names the regex it stands for. Paths are POSIX; only ASCII counts as whitespace.
(import ./frontmatter :as fm)
(import ./find)
(import spork/sh)
(import tomlin)

(def TYPES ["project" "milestone" "wave" "slice" "task"]) # high → low
(def PHASES ["initialize" "execute" "finalize"])
(def RECORDS
  {"decision" {:dir "decisions" :prefix "D" :durable true}
   "learning" {:dir "learnings" :prefix "L" :durable true}
   "backlog" {:dir "backlog" :prefix "B" :durable false}})
(def RECORD-KINDS ["decision" "learning" "backlog"])
(def HARVEST-KINDS ["decision" "learning" "backlog" "process"])
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

# Exit codes; a program running dev-proc over many directories tells these apart without reading stderr.
(def EXIT-FAILURE 1)
(def EXIT-USAGE 2)
(def EXIT-NO-WORK-DIR 3)

(defn- die [msg] (error @{:usage msg}))
(defn- die-no-work-dir [msg] (error @{:no-work-dir msg}))
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
  (def d (os/date nil true)) # the local calendar day: work done after local midnight belongs to the new day
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

(defn- inside? [top p] (let [r (rel top p)] (not (or (= r "..") (string/has-prefix? "../" r)))))

# A path as the person reads it: relative to the repo when inside it, absolute when not.
(defn- shown [top p]
  (if (and top (inside? top p)) (let [r (rel top p)] (if (empty? r) "." r)) p))

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

# The repo's top, or nil outside a git repo.
(defn- repo-top [cwd]
  (def [code out] (run-git ["rev-parse" "--show-toplevel"] cwd))
  (when (= code 0) (fm/jtrim out)))

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

# /^## <heading>\s*$([\s\S]*?)(?=^## |(?![\s\S]))/m : [text-start text-end heading-line-end] of the section
(defn- section-range [body heading]
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
        (set res [p q (eol body k)])))
    (++ i))
  res)

# the section text after the heading line
(defn- section [body heading]
  (if-let [[p q] (section-range body heading)] (string/slice body p q) ""))

(defn- need-section [body heading]
  (or (section-range body heading) (die (string "no \"## " heading "\" section"))))

# [text before the first "## " heading, [[heading text] …]]; "## " lines inside code fences are content.
(defn- split-sections [text]
  (def pre @"")
  (def out @[])
  (var fence false)
  (each raw (string/split "\n" text)
    (def line (if (string/has-suffix? "\r" raw) (string/slice raw 0 -2) raw)) # CRLF files read like LF ones
    (def t (fm/jtrim line))
    (def heading? (and (not fence) (string/has-prefix? "## " line)))
    (when (or (string/has-prefix? "```" t) (string/has-prefix? "~~~" t)) (set fence (not fence)))
    (cond
      heading? (array/push out @[(fm/jtrim (string/slice line 3)) @[]])
      (empty? out) (buffer/push pre line "\n")
      (array/push ((last out) 1) line)))
  [(string pre) (map (fn [[h ls]] [h (string/join ls "\n")]) out)])

# The section's body becomes `text`; the heading line and every other section stay as they are.
(defn- replace-section [body heading text]
  (def [_ q hend] (need-section body heading))
  (def t (fm/jtrim text))
  (string (string/slice body 0 hend) "\n" (if (empty? t) "" (string t "\n"))
          (if (< q (length body)) (string "\n" (string/slice body q)) "")))

# `line` joins the section's end, in front of the blank line that separates it from the next one.
(defn- append-to-section [body heading line]
  (def [_ q hend] (need-section body heading))
  (var e q)
  (while (and (> e hend) (fm/ws? (body (- e 1)))) (-- e))
  (string (string/slice body 0 e) "\n" line "\n" (if (< q (length body)) (string "\n" (string/slice body q)) "")))

# An occurrence at j is a /^\s*<lit>/m match when only whitespace lies between it and a line start.
(defn- at-line-start-ws? [s j]
  (var k j)
  (var nl false)
  (while (and (> k 0) (fm/ws? (s (- k 1))))
    (-- k)
    (when (or (= (s k) 10) (= (s k) 13)) (set nl true)))
  (or (= k 0) nl))

# /<!--[\s\S]*?-->/ removed, as HTML reads comments: they do not nest, and an unclosed one stays.
(defn- strip-html-comments [text]
  (def clean @"")
  (var i 0)
  (while (< i (length text))
    (def open (string/find "<!--" text i))
    (def close (when open (string/find "-->" text (+ open 4))))
    (if close
      (do (buffer/push clean (string/slice text i open)) (set i (+ close 3)))
      (do (buffer/push clean (string/slice text i)) (set i (length text)))))
  (string clean))

# [[heading text] …] in document order; the template's guidance comments are not content.
(defn- sections-of [body]
  (map (fn [[h t]] [h (fm/jtrim (strip-html-comments t))]) ((split-sections body) 1)))

(def- harvest-item-peg (peg/compile ~(* "- [" (<- (set " xX")) "]" (? " ") (<- (any 1)))))

# Harvest "- [ ] kind: text" lines as {:kind :text :done}; a kind outside decision, learning, backlog and
# process is "other". An indented line right after an item continues it. This is the one reading of
# the section: the finalize gate counts its open items and the JSON lists them.
(defn- harvest-items [text]
  (def items @[])
  (var open nil) # the item an indented line would continue
  (each line (string/split "\n" (strip-html-comments text))
    (if-let [[mark raw] (peg/match harvest-item-peg (fm/jtrim line))]
      (do
        (def rest (fm/jtrim raw))
        (def kind (or (find |(string/has-prefix? (string $ ": ") rest) HARVEST-KINDS) "other"))
        (set open @{:kind kind :done (not= mark " ")
                    :text (if (= kind "other") rest (fm/jtrim (string/slice rest (+ 2 (length kind)))))})
        (array/push items open))
      (if (and open (not (empty? (fm/jtrim line))) (fm/ws? (get line 0)))
        (put open :text (string (open :text) "\n" (fm/jtrim line)))
        (set open nil))))
  items)

(defn- count-open-items [text]
  (length (filter |(not ($ :done)) (harvest-items text))))

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

# /^<key>\s*(\S+)\s*$/gm : the captured values, e.g. for key "Work:"
(defn- trailer-values [s key]
  (def n (length s))
  (def out @[])
  (var i 0)
  (while (< i n)
    (var next (+ i 1))
    (when (and (line-start? s i) (fm/at? s i key))
      (def w1 (skip-ws s (+ i (length key))))
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

(defn- work-trailers [s] (trailer-values s "Work:"))

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

# A root is described by {:dir :base :oob}. :base is the project dir its refs resolve against and
# whose files it owns in commits. An out-of-band (:oob) root is one person's own: it sits outside the
# repo or is git-ignored, and the commit hooks and trailers never ask for it or name it.
(defn- load-root [desc]
  (def dir (desc :dir))
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
  @{:dir dir :base (desc :base) :oob (desc :oob) :units units :records records})

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

# The person's own root, from `git config dev-proc.root`: clone-local (or global) git config, so it
# never lands in the repo. A relative path is taken from the repo top; git expands a leading ~.
# Outside a git repo there is none: a global setting is meant for the person's repos, and a second
# way to set it would be a second thing to keep in step.
(defn- configured-root [ctx]
  (when (ctx :git)
    (def v (fm/jtrim (try-git ["config" "--type=path" "--get" "dev-proc.root"] (ctx :top))))
    (when (some-str v) (resolve (ctx :top) v))))

(defn- ignored? [top p] (= 0 ((run-git ["check-ignore" "-q" p] top) 0)))

# The top of the git repo that keeps a root's history, or nil: none when the root is in no repo or
# is git-ignored in the one it sits in. close and record --supersedes delete files on the premise
# that history keeps them, so a root without it archives them in closed/ instead.
(defn- history-top [dir]
  (def [code out] (run-git ["rev-parse" "--show-toplevel"] dir))
  (when (= code 0)
    (def top (fm/jtrim out))
    (unless (ignored? top dir) top)))

# Where a root without history keeps what close and record --supersedes remove. load-root reads only
# the type and record dirs, so nothing in here is seen by status, find or check.
(def CLOSED "closed")

(defn- archive [root path & sub]
  (def dest (pjoin (root :dir) CLOSED ;sub (basename path)))
  (when (exists? dest) (die (string dest " already exists")))
  (mkdirp (dirname dest))
  (os/rename path dest)
  dest)

# A directory may name its own work dir: work_dir in <dir>/.dev-proc.toml, a file the team commits.
# Without the file the name is .work. The setting covers that directory only, not those below it.
(def CONFIG ".dev-proc.toml")
(def DEFAULT-WORK ".work")

(defn- read-config [top file]
  (def where (shown top file))
  (def [ok cfg] (protect (tomlin/toml->janet (read-file file))))
  (unless ok (die (string where ": " cfg)))
  (each k (keys cfg)
    (unless (= (string k) "work_dir") (die (string where ": unknown key \"" k "\"; the only one is work_dir"))))
  (def w (get cfg :work_dir))
  (cond
    (nil? w) DEFAULT-WORK
    (and (string? w) (not (empty? w)) (not (index-of w ["." ".."]))
         (not (string/find "/" w)) (not (string/find "\\" w))) w
    (die (string where ": work_dir must be one directory name, such as \".work\""))))

# A git-ignored file is skipped, as `git ls-files` (all-roots) would skip it: the setting is shared,
# and honouring it in one command but not another would split the commands' view of the repo.
(defn- work-name [top d]
  (def file (pjoin d CONFIG))
  (cond
    (not (exists? file)) DEFAULT-WORK
    (and top (inside? top file) (ignored? top file))
    (do (eprint "dev-proc: warn  " (shown top file) " is git-ignored, so it is skipped; commit it to rename the work dir")
        DEFAULT-WORK)
    (read-config top file)))

(defn- root-desc [dir top configured]
  (cond
    (or (= dir configured) (not (inside? top dir))) {:dir dir :base top :oob true}
    {:dir dir :base (dirname dir) :oob (ignored? top dir)}))

# Every .work/ root in the repo, honouring .gitignore; includes untracked ones, then the
# configured root, if any. Outside a git repo, only the root the command runs against: finding the
# rest would mean walking the tree with git's ignore rules rebuilt by hand.
(defn- all-roots [ctx]
  (unless (ctx :git) (break @[((ctx :root-desc))]))
  (def top (ctx :top))
  (def configured (configured-root ctx))
  (def names @{}) # dir -> its work dir name, read once
  (defn name-of [d] (unless (names d) (put names d (work-name top d))) (names d))
  (def roots @{})
  (each f (string/split "\0" (git ["ls-files" "-z" "--cached" "--others" "--exclude-standard"] top))
    (def segs (string/split "/" f))
    (when (= (last segs) CONFIG)
      (def d (pjoin top ;(slice segs 0 -2)))
      (put roots (pjoin d (name-of d)) true))
    (when-let [i (index-of DEFAULT-WORK segs)]
      (def d (pjoin top ;(slice segs 0 i)))
      (when (= DEFAULT-WORK (name-of d)) (put roots (pjoin d DEFAULT-WORK) true))))
  (def out (map |(root-desc $ top configured)
                (sort (filter |(and (exists? $) (not= $ configured)) (keys roots)))))
  (when (and configured (exists? configured))
    (array/push out (root-desc configured top configured)))
  out)

(defn- nearest-root [cwd top]
  (var d cwd)
  (var res nil)
  (while true
    (def w (pjoin d (work-name top d)))
    (when (exists? w) (set res w) (break))
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

# What a creating command prints: only the id (--id), one JSON object (--json), or the human lines.
(defn- report [args id obj & lines]
  (cond
    (args "id") (print id)
    (args "json") (print-json obj)
    (each l lines (print l))))

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
  (def dir (if-let [d (first (args :pos))]
             (let [p (resolve (ctx :cwd) d)] (pjoin p (work-name (ctx :top) p)))
             (or (when (some-str (args "root")) (resolve (ctx :cwd) (args "root")))
                 (configured-root ctx)
                 (pjoin (ctx :cwd) (work-name (ctx :top) (ctx :cwd))))))
  (if (exists? dir)
    (print "exists: " dir)
    (do
      (mkdirp dir)
      (spit (pjoin dir ".gitkeep") "")
      (print "created " (shown (ctx :top) dir) "/"))))

(defn- unit-line [u]
  (def front (u :fm))
  (def owner (let [o (string/join (list-of (fm/fm-get front "owner")) ", ")] (if (empty? o) "—" o)))
  (def warn (if (empty? (u :problems)) "" (string "  ⚠ " (string/join (u :problems) "; "))))
  (string (show u) "  [" (jstr (or (fm/fm-get front "phase") "?")) "]  owner: " owner warn))

# A scalar front matter field as JSON: always a string, a list joined by ", "; nil (left out) when unset.
(defn- fm-string [front k]
  (def v (fm/fm-get front k))
  (some-str (if (string? v) v (string/join (or v []) ", "))))

# A list field as JSON: always an array, a single string being a list of one; nil (left out) when empty.
(defn- fm-list [front k]
  (def items (list-of (fm/fm-get front k)))
  (unless (empty? items) (array ;items)))

# Section text as an array of {heading, text} in document order: JSON objects decode unordered, and a
# heading may repeat.
(defn- sections-json [body]
  (map (fn [[h t]] (jobj "heading" h "text" t)) (sections-of body)))

(defn- harvest-json [body]
  (map |(jobj "kind" ($ :kind) "text" ($ :text) "done" ($ :done)) (harvest-items (section body "Harvest"))))

# What a viewer needs of a unit beyond its place in the tree.
(defn- unit-detail [u]
  ["sections" (sections-json (u :body)) "harvest" (harvest-json (u :body))])

# The front matter fields a record may carry, by how they read; one its kind lacks is left out.
# Other fields are not passed on.
(def- RECORD-SCALARS ["created" "date" "status" "priority" "needs"])
(def- RECORD-LISTS ["refs" "supersedes"])

(defn- record-fields [r]
  [;(mapcat |[$ (fm-string (r :fm) $)] RECORD-SCALARS)
   ;(mapcat |[$ (fm-list (r :fm) $)] RECORD-LISTS)])

(defn- record-json [r detail?]
  (jobj "id" (or (r :id) :null) "kind" (r :kind) "title" (title-of (r :body))
        "read_if" (list-of (fm/fm-get (r :fm) "read_if"))
        ;(record-fields r)
        "problems" (r :problems)
        ;(if detail? ["sections" (sections-json (r :body))] [])))

(defn- status-record [ctx r args]
  (if (args "json")
    (print-json (record-json r true))
    (do
      (print (title-of (r :body)) "  [" (r :kind) "]")
      (print "file: " (shown (ctx :top) (r :file)))
      (each [k v] (partition 2 (record-fields r))
        (when v (print k ": " (if (string? v) v (string/join v ", ")))))
      (unless (empty? (r :problems))
        (print "problems:\n  ⚠ " (string/join (r :problems) "\n  ⚠ "))))))

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
                      "next" next-phase "gate" gate "problems" (u :problems)
                      "created" (fm-string front "created") "awaiting" (fm-string front "awaiting")
                      ;(unit-detail u)))
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
    (if (peg/match record-id-peg id)
      (status-record ctx (find-record root id) args)
      (status-one ctx root (find-unit root id) args))
    (break))
  (def units (root :units))
  (if (args "json")
    (print-json
      (jobj "root" (shown (ctx :top) (root :dir))
            "units" (map (fn [u]
                           (def front (u :fm))
                           (jobj "id" (u :id) "label" (u :label) "phase" (or (fm/fm-get front "phase") :null)
                                 "parent" (or (parent-of u) :null) "owner" (list-of (fm/fm-get front "owner"))
                                 "problems" (u :problems) "created" (fm-string front "created")
                                 "awaiting" (fm-string front "awaiting")
                                 ;(if (args "detail") (unit-detail u) [])))
                         units)
            "records" (map |(record-json $ (args "detail")) (root :records))))
    (do
      (print "root: " (shown (ctx :top) (root :dir)) (if (root :oob) "  (out-of-band)" ""))
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

# The body given with --body - (stdin) or --body-file: each "## Heading" block replaces the section of
# that name in the template `text`. `taken` names sections another flag has already filled.
(defn- apply-body [ctx args text taken]
  (when (and (args "body") (args "body-file")) (die "give --body or --body-file, not both"))
  (def src
    (cond
      (args "body-file") (read-file (resolve (ctx :cwd) (args "body-file")))
      (args "body") (if (= (args "body") "-")
                      (string (or (file/read stdin :all) ""))
                      (die "--body takes - (read stdin); use --body-file for a file"))))
  (if (nil? src)
    text
    (do
      (def [pre blocks] (split-sections src))
      (unless (empty? (fm/jtrim pre)) (die "the body must start with a \"## Heading\" line"))
      (def valid (map |($ 0) ((split-sections text) 1)))
      (def seen @{})
      (var out text)
      (each [h b] blocks
        (unless (index-of h valid)
          (die (string "no section \"" h "\" in the template; valid: " (string/join valid ", "))))
        (when (or (seen h) (index-of h taken)) (die (string "section \"" h "\" is given twice")))
        (put seen h true)
        (set out (replace-section out h b)))
      out)))

# Moves the unit through the gate and returns the line to report; dies when the gate is closed.
(defn- move-phase [root u to force]
  (unless (index-of to PHASES)
    (die (string "phase must be one of: " (string/join PHASES ", ") " (use `close` to end a unit)")))
  (def from (fm/fm-get (u :fm) "phase"))
  (if (= from to)
    (string (show u) " already in " to)
    (do
      (def forward (> (index-of to PHASES) (or (and (string? from) (index-of from PHASES)) -1)))
      (def problems (if forward (gate-problems root u to) @[]))
      (when (and (not (empty? problems)) (not force))
        (die (string "gate → " to " closed:\n  ✗ " (string/join problems "\n  ✗ ")
                     "\n(--force to override, and say why in the Log)")))
      (spit (u :state-path) (dump-doc (fm-set (u :fm) "phase" to) (u :body)))
      (append-log (u :state-path)
                  (string "phase " (jstr from) " → " to
                          (if (and force (not (empty? problems))) " (forced)" "")))
      (string (show u) ": " (jstr from) " → " to))))

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
  (def backlog
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
      b))

  (def owner (if (some-str (args "owner"))
               (map fm/jtrim (string/split "," (args "owner")))
               @["TODO: person and/or agent"]))
  (def criteria (list-of (args "criterion")))
  (def front @[@["phase" "initialize"] @["parent" parent] @["owner" owner] @["created" (today)]
               @["success_criteria" (if (empty? criteria)
                                      @["TODO: observable outcome that proves this unit is done"]
                                      criteria)]])
  (def vars {"id" id "label" lbl "date" (today)})
  # Everything that can fail is built before the first file is touched.
  (var state (template "STATE.md" vars))
  (def purpose (some-str (args "purpose")))
  (when purpose (set state (replace-section state "Purpose" purpose)))
  (set state (apply-body ctx args state (if purpose ["Purpose"] [])))
  # The marker sits in Context & constraints, which a body may have replaced.
  (unless (empty? (fm/jtrim origin))
    (set state (if (string/find "<!-- origin -->" state)
                 (replace-first state "<!-- origin -->" origin)
                 (append-to-section state "Context & constraints" (string "\n" (fm/jtrim origin))))))
  (set state (replace-first state "<!-- origin -->" ""))
  (def designs (seq [f :in (filter |(not= $ "") (string/split "," (or (args "with") "")))]
                 (or (get {"design" "DESIGN.md" "plan" "PLAN.md"} (fm/jtrim f)) (die "--with takes design,plan"))))

  (when backlog (sh/rm (backlog :file)))
  (def dir (pjoin (root :dir) type (string id "-" name)))
  (mkdirp dir)
  (spit (pjoin dir "STATE.md") (dump-doc front state))
  (def created @["STATE.md"])
  (each file designs
    (spit (pjoin dir file) (template file vars))
    (array/push created file))

  # --execute runs the gate of `phase <unit> execute`; the unit exists either way.
  (def gate
    (when (args "execute")
      (def fresh (load-root root))
      (protect (move-phase fresh (find-unit fresh id) "execute" false))))
  (report args id
          (jobj "id" id "label" lbl "type" type "name" name "path" (shown (ctx :top) dir)
                "phase" (if (and gate (gate 0)) "execute" "initialize")
                "files" created "consumed" (some-str (args "from")))
          (string "created " id " " lbl ": " (shown (ctx :top) dir) "/ {" (string/join created ", ") "}  mode: initialize")
          ;(if backlog [(string "consumed backlog " (args "from"))] [])
          ;(if (and gate (gate 0)) [(gate 1)] []))
  (when (and gate (not (gate 0))) (error (gate 1))))

(defn- cmd-phase [ctx args]
  (def [id to] (args :pos))
  (def root ((ctx :root)))
  (print (move-phase root (find-unit root id) to (args "force"))))

(def NOTE-SECTIONS {"now" "Now" "next" "Next" "evidence" "Evidence" "harvest" "Harvest" "log" "Log"})

(defn- cmd-note [ctx args]
  (def [ref sec & words] (args :pos))
  (def heading (get NOTE-SECTIONS sec))
  (unless (and ref heading) (die (string "usage: note <unit> <" (string/join (sort (keys NOTE-SECTIONS)) "|") "> \"text\"")))
  (def text (fm/jtrim (string/join (or words []) " ")))
  (when (empty? text) (die "a note needs text"))
  (def u (find-unit ((ctx :root)) ref))
  (need-section (u :body) heading)
  (case sec
    "log" (append-log (u :state-path) text)
    (spit (u :state-path)
          (dump-doc (u :fm)
                    (case sec
                      "evidence" (append-to-section (u :body) heading (string "- " text))
                      "harvest" (append-to-section (u :body) heading (string "- [ ] " text))
                      (replace-section (u :body) heading text)))))
  (print (show u) ": " sec " updated"))

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
  (unless (history-top (root :dir))
    # Nothing would keep a deleted copy, so it is kept here, and there is no commit to name it in.
    (def dest (archive root (u :dir) (u :type)))
    (print "moved " (show u) " to " (shown (ctx :top) dest) "/ — the work dir has no git history to keep it")
    (break))
  (sh/rm (u :dir))
  (when (root :oob)
    # Out-of-band work stays out of the team's commits, trailers included.
    (print "deleted " (shown (ctx :top) (u :dir)) "/")
    (break))
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
  (def text (apply-body ctx args (template (string kind ".md") {"id" id "title" title "date" (today)}) []))
  (mkdirp (dirname file))
  (spit file (dump-doc front text))
  (def kept (unless (or (empty? old) (history-top (root :dir))) true))
  (each r old (if kept (archive root (r :file) (spec :dir)) (os/rm (r :file))))
  (def ids (string/join (map |($ :id) old) ", "))
  (report args id
          (jobj "id" id "kind" kind "path" (shown (ctx :top) file)
                "superseded" (unless (empty? old) (map |($ :id) old)))
          (string "created " (shown (ctx :top) file))
          ;(cond
             (empty? old) []
             kept [(string "moved " ids " to " (shown (ctx :top) (pjoin (root :dir) CLOSED (spec :dir)))
                           "/ — the work dir has no git history to keep it")]
             # Out-of-band ids stay out of the team's commits.
             (root :oob) [(string "deleted " ids)]
             [(string "deleted " ids " — add to the commit message:")
              ;(map |(string "  Supersedes: " ($ :id)) old)])))

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
  (each r (filter |(not ($ :oob)) roots)
    (def base-rel (rel top (r :base)))
    (when (and (or (= base-rel "") (string/has-prefix? (string base-rel "/") file))
               (or (nil? best) (> (length (r :base)) (length (best :base)))))
      (set best r)))
  best)

# The roots with an executing unit where code is staged but no unit's STATE.md is: what the
# pre-commit check rejects. Each is {:root-rel … :executing [units whose STATE.md would satisfy it]}.
(defn- state-gaps [roots top staged]
  (def out @[])
  (each root (filter |(not ($ :oob)) roots)
    (def root-rel (rel top (root :dir)))
    (def executing (filter |(= (fm/fm-get ($ :fm) "phase") "execute") (root :units)))
    (unless (empty? executing)
      (def mine (filter |(= (owning-root roots top $) root) staged))
      (def code (some |(not (string/has-prefix? (string root-rel "/") $)) mine))
      (def state (some |(and (string/has-prefix? (string root-rel "/") $) (string/has-suffix? "/STATE.md" $)) mine))
      (when (and code (not state))
        (array/push out {:root-rel root-rel :executing executing}))))
  out)

# Roots that hold a staged file, in staged order.
(defn- touched-roots [roots top staged]
  (def out @[])
  (each f staged
    (when-let [r (owning-root roots top f)]
      (unless (find |(= $ r) out) (array/push out r))))
  out)

(defn- cmd-check [ctx args]
  # The hooks guard what is committed, so they leave out-of-band roots alone.
  (def configured (configured-root ctx))
  (def roots (filter |(not (and (args "hook") ($ :oob))) (map load-root (all-roots ctx))))
  (def errors @[])
  (def warns @[])
  (each root roots
    (def where (shown (ctx :top) (root :dir)))
    # A .work left beside a renamed work dir is no longer read, so whatever is in it is lost from view.
    (unless (= (root :dir) configured)
      (def old (pjoin (dirname (root :dir)) DEFAULT-WORK))
      (when (and (not= old (root :dir)) (exists? old))
        (array/push warns (string (shown (ctx :top) old) ": not read, since " CONFIG " names "
                                  (basename (root :dir)) " as the work dir; move what it holds and remove it"))))
    (when (and (root :oob) (inside? (ctx :top) (root :dir)) (not (ignored? (ctx :top) (root :dir))))
      (array/push warns (string where ": out-of-band root is inside the repo but not git-ignored, so its files"
                                " would be committed; add it to .git/info/exclude")))
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
      (def at (shown (ctx :top) (r :file)))
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
    (each g (state-gaps roots (ctx :top) (staged-files (ctx :top)))
      (array/push (if (strict?) errors warns)
                  (string (g :root-rel) ": code changed under an executing unit but no STATE.md is staged — keep docs current in every commit"))))

  (each w warns (print "warn  " w))
  (each e errors (print "error " e))
  (when (and (empty? errors) (empty? warns))
    (print "ok (" (length roots) " root" (if (= (length roots) 1) "" "s") ")"))
  (when (and (not (empty? errors)) (or (not (args "hook")) (strict?))) (put ctx :exit EXIT-FAILURE)))

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
    (seq [d :in (all-roots ctx)
          r :in ((load-root d) :records)
          :when (and (kinds (r :kind)) (r :id) (r :fm))]
      {:id (r :id) :kind (r :kind) :root (shown (ctx :top) (d :dir))
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
  (def roots (map load-root (all-roots ctx)))
  (def active (some |(not (empty? ($ :units))) (touched-roots roots (ctx :top) (staged-files (ctx :top)))))
  (def trailers (work-trailers msg))
  (def out @[])
  (when (and active (empty? trailers))
    (array/push out "no \"Work: U-…\" trailer, but staged changes fall under active units"))
  (each t trailers
    (unless (peg/match unit-id-peg t)
      (array/push out (string "trailer \"Work: " t "\" is not a unit id (U-<16 base32 chars>)"))))
  (each o out (print (if (strict?) "error" "warn ") " " o))
  (when (and (not (empty? out)) (strict?)) (put ctx :exit EXIT-FAILURE)))

(defn- cmd-trailers [ctx args]
  (def top (ctx :top))
  (def roots (map load-root (all-roots ctx)))
  (def staged (staged-files top))
  # A unit is named by the directory of any staged file, so a unit deleted by `close` counts too.
  (def found @[])
  (each f staged
    (when-let [r (owning-root roots top f)]
      (def segs (string/split "/" (string/slice f (min (length f) (+ 1 (length (rel top (r :dir))))))))
      (when-let [rk (index-of (get segs 0) TYPES)
                 m (peg/match unit-dir-peg (get segs 1 ""))]
        (unless (find |(= ($ 0) (m 0)) found) (array/push found [(m 0) rk (length found)])))))
  # Most specific unit first, ties in staged order.
  (each [id] (sorted found (fn [a b] (or (> (a 1) (b 1)) (and (= (a 1) (b 1)) (< (a 2) (b 2))))))
    (print "Work: " id))
  # The hooks ask for nothing further: any one valid Work: trailer satisfies check-msg.
  (each g (state-gaps roots top staged)
    (eprint "warn  " (g :root-rel) ": code is staged under an executing unit but no STATE.md is; the pre-commit check passes once one of these is staged: "
            (string/join (map |(rel top (pjoin ($ :dir) "STATE.md")) (g :executing)) ", ")))
  (when (and (empty? found) (some |(not (empty? ($ :units))) (touched-roots roots top staged)))
    (eprint "warn  staged changes fall under active units, but no unit file is staged to name one")))

# What a repo path is to dev-proc, wherever its work dir sits or was: a unit's file
# ({:unit :type :name :file}, from <type>/U-…-<name>/<file>), a record ({:record :kind}, from
# <kind dir>/X-….md), or nil. dig and report recognise history through this alone.
(defn- work-path [f]
  (def segs (string/split "/" f))
  (var res nil)
  (for i 0 (- (length segs) 2)
    (unless res
      (when-let [_ (index-of (segs i) TYPES) m (peg/match unit-dir-peg (segs (+ i 1)))]
        (set res {:unit (m 0) :type (segs i) :name (m 1) :file (string/join (slice segs (+ i 2)) "/")}))))
  (or res
      (when (>= (length segs) 2)
        (def m (peg/match file-id-peg (last segs)))
        (def kind (find |(= ((RECORDS $) :dir) (segs (- (length segs) 2))) RECORD-KINDS))
        (when (and m kind (string/has-suffix? ".md" (last segs))
                   (= (string/slice (m 0) 0 1) ((RECORDS kind) :prefix)))
          {:record (m 0) :kind kind}))))

(defn- dig-closed [ctx root id]
  (def closed (pjoin (root :dir) CLOSED))
  (def hits @[])
  (defn walk [d]
    (each e (sort (os/dir d))
      (def p (pjoin d e))
      (cond
        (dir? p) (walk p)
        (let [w (work-path (rel closed p))] (= id (or (get w :unit) (get w :record)))) (array/push hits p))))
  (when (exists? closed) (walk closed))
  (when (empty? hits)
    (die (string "no closed copy of " id " in " (shown (ctx :top) closed) "; the work dir has no git history")))
  (print "closed; the work dir has no git history, so the last version is kept in "
         (shown (ctx :top) closed) "/:\n")
  (each f hits
    (print "===== " (shown (ctx :top) f))
    (print (read-file f))))

(defn- cmd-dig [ctx args]
  (def id (or (first (args :pos)) (die "usage: dig <U-… | D-… | L-… | B-…>")))
  (def root ((ctx :root)))
  # An out-of-band root has no history in this repo; when it sits in a repo of its own, dig there.
  # A root with no history at all kept what it closed in closed/.
  (def htop (history-top (root :dir)))
  (unless htop (break (dig-closed ctx root id)))
  (def top (if (root :oob) htop (ctx :top)))
  # Ids are unique, so the whole repo is searched: a work dir renamed or moved since keeps its history.
  (def rec (peg/match record-id-peg id))
  (var pathspec nil)
  (var matches nil)
  (if rec
    (do
      (set pathspec [(string ":(glob)**/" id "-*.md") (string ":(glob)**/" id ".md")])
      (set matches (fn [f] (= id (get (work-path f) :record)))))
    (do
      (unless (peg/match unit-id-peg id) (die "dig takes an id (U-…, D-…, L-…, B-…); names are reused, ids are not"))
      (set pathspec [(string ":(glob)**/" id "-*/**")])
      # Any type dir: the unit may have been rescoped between commits.
      (set matches (fn [f] (= id (get (work-path f) :unit))))))

  (def trail (fm/jtrim (try-git ["log" "--all" "--date=short" "--format=%h %ad %s" "-E"
                                 (string "--grep=^(Work|Supersedes|Decision): " id "$")] top)))
  (unless (empty? trail)
    (print "commits with a trailer for " id ":\n"
           (string/join (map |(string "  " $) (string/split "\n" trail)) "\n") "\n"))

  (def log (try-git ["log" "--all" "--no-renames" "--diff-filter=D" "--format=@@%H %h %ad" "--date=short"
                     "--name-only" "--" ;pathspec] top))
  (def deletions
    (filter |(not (empty? ($ :files)))
            (seq [block :in (string/split "@@" log) :unless (empty? block)]
              (def [head & files] (string/split "\n" (fm/jtrim block)))
              (def [full short date] (string/split " " head))
              {:full full :short short :date date :files (filter |(and (not= $ "") (matches $)) files)})))
  (when (empty? deletions)
    (when (empty? trail) (die (string "no history found for " id " in " top)))
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

(def REPORT-HELP
  `usage: report [<range>] [--since <date>] [--json]

What dev-proc work a stretch of git history holds: the units delivered, scrapped or still open, with
the commits each carries a Work: trailer on, and the records added and removed. <range> is a git range
(a..b), or a revision meaning <rev>..HEAD; with neither <range> nor --since it is <last tag>..HEAD, or
all of HEAD's history when there is no tag. --since takes what git log --since takes. Read from git
alone, so uncommitted work is left out (status shows it).`)

# A unit as of revision `tip`: its type, name and parent, from the last version of its STATE.md.
(defn- unit-at [top tip id]
  (def log (fm/jtrim (try-git ["log" "-1" "--no-renames" "--format=%h" "--name-status" tip "--"
                               (string ":(glob)**/" id "-*/STATE.md")] top)))
  (def lines (string/split "\n" log))
  # A rescope deletes the old path and adds the new one in one commit; the new one is the unit.
  (def changes (filter |(string/find "\t" $) lines))
  (def change (or (find |(not (string/has-prefix? "D" $)) changes) (first changes)))
  (when change
    (def [st f] (string/split "\t" change))
    (def w (work-path f))
    (def rev (if (= st "D") (string (lines 0) "^") (lines 0)))
    (def [ok d] (protect (fm/parse-doc (try-git ["show" (string rev ":" f)] top))))
    (def p (when ok (fm/fm-get (d :fm) "parent")))
    {:type (w :type) :name (w :name) :label (string (w :type) "/" (w :name)) :parent (when (string? p) p)}))

(defn- cmd-report [ctx args]
  (when (or (args "help") (index-of "-h" (args :pos))) (print REPORT-HELP) (break))
  (def top (ctx :top))
  (def arg (some-str (first (args :pos))))
  (def since (some-str (args "since")))
  (def range (cond arg (if (string/find ".." arg) arg (string arg "..HEAD"))
                   since "HEAD"
                   (if-let [t (some-str (fm/jtrim (try-git ["describe" "--tags" "--abbrev=0"] top)))]
                     (string t "..HEAD")
                     "HEAD")))
  (def tip (let [i (string/find ".." range)] (if i (let [t (string/slice range (+ i 2))] (if (empty? t) "HEAD" t)) range)))
  (def [code out] (run-git ["log" "--reverse" "--no-renames" "--date=short" "--name-status"
                            "--format=%x1e%h%x1f%ad%x1f%B%x1f" ;(if since [(string "--since=" since)] []) range "--"] top))
  (unless (= code 0) (die (string "git log " range " failed; is it a range or revision of this repo?")))

  (def units @{})
  (def order @[])
  (defn unit [id] (unless (units id) (array/push order id) (put units id @{:id id :commits 0})) (units id))
  (def recs (tabseq [k :in RECORD-KINDS] k @{:added 0 :removed 0}))
  (def dates @[])
  (each block (string/split "\x1e" out)
    (unless (empty? (fm/jtrim block))
      (def [_ date msg files] (string/split "\x1f" block))
      (array/push dates date)
      (each t (work-trailers msg) (when (peg/match unit-id-peg t) (update (unit t) :commits inc)))
      # A unit's STATE.md added starts it and deleted closes it; both in one commit is a rescope.
      (def adds @{})
      (def dels @{})
      (each line (string/split "\n" (or files ""))
        (def [st f] (string/split "\t" line))
        (when-let [_ f w (work-path f)]
          (cond
            (and (w :unit) (= (w :file) "STATE.md"))
            (case st "A" (put adds (w :unit) true) "D" (put dels (w :unit) true))
            (w :record)
            (case st "A" (update-in recs [(w :kind) :added] inc) "D" (update-in recs [(w :kind) :removed] inc)))))
      (def scrap (not (empty? (trailer-values msg "Decision:"))))
      (eachk id adds (unless (dels id) (put (unit id) :started true)))
      (eachk id dels (unless (adds id) (put (unit id) :outcome (if scrap "scrapped" "delivered"))))))

  (def info @{})
  (defn info-of [id] (unless (info id) (put info id (or (unit-at top tip id) {}))) (info id))
  (def rows (seq [id :in order :let [u (units id) i (info-of id)]]
              @{:id id :label (i :label) :type (i :type) :name (i :name)
                :outcome (or (u :outcome) "open") :started (truthy? (u :started)) :commits (u :commits)
                :parent (i :parent) :parent-label (when (i :parent) ((info-of (i :parent)) :label))}))
  (def from (first dates))
  (def to (last dates))
  (if (args "json")
    (print-json
      (jobj "range" range "since" (or since :null) "commits" (length dates) "from" (or from :null) "to" (or to :null)
            "units" (map |(jobj "id" ($ :id) "label" (or ($ :label) :null) "outcome" ($ :outcome) "started" ($ :started)
                                "commits" ($ :commits) "parent" (or ($ :parent) :null) "parentLabel" (or ($ :parent-label) :null))
                         rows)
            "records" (jobj ;(mapcat |[$ (jobj "added" (get-in recs [$ :added]) "removed" (get-in recs [$ :removed]))]
                                     RECORD-KINDS))))
    (do
      (print range (if since (string " since " since) "") ": " (length dates) " commit" (if (= 1 (length dates)) "" "s")
             (cond (nil? from) "" (= from to) (string ", " from) (string ", " from " – " to)))
      (each outcome ["delivered" "scrapped" "open"]
        (def these (filter |(= ($ :outcome) outcome) rows))
        (unless (empty? these)
          (print outcome)
          (each r these
            (print "  " (r :id) " " (or (r :label) "(no STATE.md in history)") "  " (r :commits) " commit" (if (= 1 (r :commits)) "" "s")
                   (if (and (= outcome "open") (r :started)) "  new" "")
                   (if (r :parent-label) (string "  in " (r :parent-label)) "")))))
      (when (empty? rows) (print "no units"))
      (print "records  "
             (string/join (map (fn [k] (def c (recs k))
                                 (string ((RECORDS k) :dir) " +" (c :added) (if (> (c :removed) 0) (string " −" (c :removed)) "")))
                               RECORD-KINDS)
                          "  ")))))

(def HELP
  (string "dev-proc — units (" (string/join TYPES " > ") ") moving " (string/join PHASES " → ") "\n\n"
    `  init [dir]                               create <dir>'s work dir (cwd if no dir), or with no dir the
                                           --root (or DEV_PROC_ROOT) dir, else the dev-proc.root dir, if set
  <unit> is a unit id (U-…) or, for active units, its <type>/<name> label

  status [<unit>|<record>] [--json] [--detail]
                                           tree of units, or one unit's mode + gate, or one record. --json
                                           gives a unit or record its sections and a unit its harvest
                                           items; with --json, --detail gives every unit and record in the
                                           tree the same
  find <words…> [--backlog] [--json]       decisions and learnings whose read_if or title match what you are about to do
  new <type> <name> [--parent <unit>] [--owner a,b] [--from B-…] [--with design,plan]
      [--criterion "…"]… [--purpose "…"] [--execute] [--id|--json] [body]
                                           --criterion fills success_criteria, --purpose the Purpose section;
                                           --execute then passes the gate of "phase <unit> execute" (the unit is
                                           kept and the exit is nonzero when owner or criteria are missing);
                                           --id prints only the id, --json one object
  phase <unit> <phase>      [--force]      move a unit (forward moves are gated)
  note <unit> <now|next|evidence|harvest|log> "text"
                                           now/next replace that section; evidence/harvest/log append one line
                                           (log gets today's date, harvest "backlog: …" becomes "- [ ] backlog: …")
  rescope <unit> [--type t] [--name n] [--parent <unit>|none]
  close <unit> [--scrap --decision D-…]   delete a finalized unit's docs; a work dir with no git history
                                           (in no repo, or git-ignored) moves them to its closed/ instead,
                                           as record --supersedes does with the old decision, and dig reads
                                           them from there
  record <decision|learning|backlog> <title> [--read-if "…"]… [--ref path#symbol]… [--supersedes D-…,…]
      [--id|--json] [body]
  [body] = --body-file <path> | --body -   (stdin). Markdown of "## Heading" blocks; each replaces the
           template section of that name, an unknown heading is an error naming the valid ones.
  check [--staged]                         lint every .work/ root in the repo
  check-msg <file>                         lint a commit message's Work: trailer
  trailers                                 print Work: lines for the units whose files are staged, most specific
                                           first; warns on stderr when the pre-commit check would want a STATE.md
  dig <U-…|D-…|L-…|B-…>                    show deleted docs from git history
  report [<range>] [--since <date>] [--json]
                                           units delivered, scrapped and open, and records added, over a git
                                           range (default: last tag..HEAD)
  hooks install                            pre-commit + commit-msg hooks (DEV_PROC_STRICT=1 blocks)

  exit codes     0 ok; 1 or 2 any other failure; 3 no work dir found from here (nothing on stdout, so
                 status --json prints nothing). A root you named that does not exist (--root,
                 DEV_PROC_ROOT, dev-proc.root) is a failure, 2: you asked for it, so it is not "no work here"

  --root <dir>   use this .work/ instead of dev-proc.root or the nearest one above cwd
  DEV_PROC_ROOT=<abs dir>   the default for --root, so a directory can pin its work dir (e.g. an
                 .envrc with export DEV_PROC_ROOT=$PWD/.mine); it works in and out of a git repo, and
                 --root on the command line wins. Each option that holds for every command takes its
                 default from a DEV_PROC_<NAME> variable like this

  outside a git repo   the nearest work dir up to /, or --root, is the only root and its parent stands
                 in for the repo top; dev-proc.root is not read, and trailers, check-msg, check --staged,
                 hooks and report refuse

  git config dev-proc.root <path>   your own out-of-band work dir, any name and place (relative to the
                 repo top, absolute, or ~/…); it is used before the nearest .work/, find and check cover it
                 too, and the commit hooks and trailers never ask for it. Keep it outside the repo or ignored
                 (.git/info/exclude); check warns otherwise

  <dir>/.dev-proc.toml   optional and committed: work_dir = ".name" makes <dir>'s work dir .name instead
                 of .work, for every clone; it covers <dir> only, not the directories below it. work_dir is
                 one directory name and the only key
  --             end of options: later arguments are text even if they start with --
                 (note <unit> log -- "--force was needed")`))

(def COMMANDS
  {"init" cmd-init "status" cmd-status "find" cmd-find "new" cmd-new "phase" cmd-phase
   "rescope" cmd-rescope "close" cmd-close "record" cmd-record "check" cmd-check
   "check-msg" cmd-check-msg "trailers" cmd-trailers "note" cmd-note "dig" cmd-dig "hooks" cmd-hooks
   "report" cmd-report})
(def BOOLEAN {"id" true "execute" true "json" true "scrap" true "staged" true "hook" true "force" true "help" true "backlog" true "detail" true})
(def REPEATABLE {"read-if" true "ref" true "criterion" true})

# Positional arguments live under :pos; flags under their string name. A bare
# -- ends the flags, so later arguments are positional even if they start with --.
(defn- parse-args [argv]
  (def args @{:pos @[]})
  (var flags? true)
  (var i 0)
  (while (< i (length argv))
    (def a (argv i))
    (cond
      (or (not flags?) (not (string/has-prefix? "--" a))) (array/push (args :pos) a)
      (= a "--") (set flags? false)
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

# The options that hold for every command, and the environment variable that gives each its default,
# so a directory can pin them (with direnv, say) in or out of a git repo. The command line wins. A
# :path value must be absolute: a relative one would mean something else in each subdirectory.
(def ENV-OPTIONS {"root" {:env "DEV_PROC_ROOT" :path true}})

# Fills args from ENV-OPTIONS where the command line left an option out; records under :from which
# variable set it, for error messages.
(defn- env-defaults [args]
  (put args :from @{})
  (eachp [opt {:env name :path path}] ENV-OPTIONS
    (def v (some-str (os/getenv name)))
    (when (and v (nil? (args opt)))
      (when (and path (not (string/has-prefix? "/" v)))
        (die (string name " is " v ", which is not an absolute path")))
      (put args opt v)
      (put (args :from) opt name)))
  args)

# The commands that read or write commits, the index or hooks.
(def NEEDS-GIT {"trailers" true "check-msg" true "hooks" true "report" true})

(defn- run [argv]
  (def cmd (first argv))
  (when (or (nil? cmd) (= cmd "") (= cmd "help") (= cmd "--help") (= cmd "-h"))
    (print HELP)
    (break 0))
  (def f (or (COMMANDS cmd) (die (string "unknown command \"" cmd "\"\n\n" HELP))))
  (def args (env-defaults (parse-args (slice argv 1))))
  (def cwd (os/cwd))
  (def git-top (repo-top cwd))
  (when (and (nil? git-top) (or (NEEDS-GIT cmd) (and (= cmd "check") (or (args "staged") (args "hook")))))
    (die (string (if (= cmd "check") "check --staged" cmd) " needs a git repository, and " cwd " is not in one")))
  # Outside a git repo the work dir is the nearest one up to the filesystem root, or --root, and its
  # parent stands in for the repo top: refs resolve against it and paths are shown from it.
  (def loose (unless git-top
               (if (some-str (args "root")) (resolve cwd (args "root")) (nearest-root cwd nil))))
  (def top (or git-top (if loose (dirname loose) cwd)))
  (def ctx @{:cwd cwd :top top :git (not (nil? git-top)) :exit 0})
  (put ctx :root-desc
       (fn []
         (def configured (configured-root ctx))
         (def dir (cond (not git-top) loose
                        (some-str (args "root")) (resolve cwd (args "root"))
                        configured configured
                        (nearest-root cwd top)))
         (when (or (not dir) (not (exists? dir)))
           (cond
             (some-str (args "root"))
             (die (string (or ((args :from) "root") "--root") " is " dir ", which does not exist — run `dev-proc init`"))
             (and configured (= dir configured))
             (die (string "dev-proc.root is " dir ", which does not exist — run `dev-proc init`"))
             (die-no-work-dir
               (string "no work dir (.work/, or the work_dir of a " CONFIG ") found from here up to "
                       (if git-top "the repo root" "/") " — run `dev-proc init`"))))
         (root-desc dir top configured)))
  (put ctx :root (fn [] (load-root ((ctx :root-desc)))))
  (f ctx args)
  (ctx :exit))

(defn main [_ & argv]
  (def code
    (try (run argv)
      ([e]
        (cond
          (and (table? e) (e :usage)) (do (eprint "dev-proc: " (e :usage)) EXIT-USAGE)
          (and (table? e) (e :no-work-dir)) (do (eprint "dev-proc: " (e :no-work-dir)) EXIT-NO-WORK-DIR)
          (do (eprint "dev-proc: " (string e)) EXIT-FAILURE)))))
  (file/flush stdout)
  (unless (= code 0) (os/exit code)))
