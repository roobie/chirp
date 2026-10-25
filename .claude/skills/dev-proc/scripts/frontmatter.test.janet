#!/usr/bin/env chirp
# Run: chirp frontmatter.test.janet   (exits non-zero on failure)
(import yaml)
(import ./frontmatter :as f)

(var failures 0)

(defn test [name thunk]
  (def r (protect (thunk)))
  (unless (r 0)
    (++ failures)
    (eprint "FAIL " name ": " (string (r 1)))))

(defn eq [actual expected &opt note]
  (unless (deep= actual expected)
    (error (string (or note "") " expected " (string/format "%q" expected) " got " (string/format "%q" actual)))))

(defn throws [thunk pattern]
  (def r (protect (thunk)))
  (when (r 0) (error (string "expected an error matching " pattern)))
  (unless (string/find pattern (string (r 1)))
    (error (string "error " (string (r 1)) " does not match " pattern))))

# Front matter is an array of @[key value] pairs, so tests spell it that way.
(defn fm [text] ((f/parse-doc (string "---\n" text "\n---\n")) :fm))

(test "returns the whole text as body when there is no front matter"
  (fn [] (eq (f/parse-doc "Hello") {:fm nil :body "Hello"})))

(test "parses scalars"
  (fn [] (eq (f/parse-doc "---\ntitle: Hello\n---\nBody") {:fm @[@["title" "Hello"]] :body "Body"})))

(test "parses block lists, inline lists and quoted values"
  (fn []
    (eq (fm "tags:\n  - one\n  - two") @[@["tags" @["one" "two"]]])
    (eq (fm "tags: [\"one, two\", three]") @[@["tags" @["one, two" "three"]]])
    (eq (fm "title: \"a: b\"\nstatus: 'x'") @[@["title" "a: b"] @["status" "x"]])
    (eq (fm "read_if: [a, b,]") @[@["read_if" @["a" "b"]]])))

(test "block-list items with brackets are plain strings"
  (fn []
    (eq (fm "read_if:\n  - running the bench [threads]\n  - see [link](url) works")
        @[@["read_if" @["running the bench [threads]" "see [link](url) works"]]])))

(test "a scalar with brackets inside is a string"
  (fn [] (eq (fm "title: see [1]") @[@["title" "see [1]"]])))

(test "an empty value is an empty list"
  (fn []
    (eq (fm "owner:") @[@["owner" @[]]])
    (eq (fm "read_if: []") @[@["read_if" @[]]])))

(test "an empty block is an empty front matter"
  (fn [] (eq ((f/parse-doc "---\n\n---\nx") :fm) @[])))

(test "handles CRLF and comments"
  (fn []
    (eq ((f/parse-doc "---\r\ntitle: A\r\nread_if:\r\n  - x\r\n---\r\nbody") :fm) @[@["title" "A"] @["read_if" @["x"]]])
    (eq (fm "# comment\n\na: b") @[@["a" "b"]])))

(test "rejects duplicate keys and malformed YAML"
  (fn []
    (throws |(f/parse-doc "---\ntitle: A\ntitle: B\n---\n") "invalid front matter")
    (throws |(f/parse-doc "---\n  - orphan\n---\n") "invalid front matter")
    (throws |(f/parse-doc "---\na: 1\nnot a pair\n---\n") "invalid front matter")))

(test "rejects values that are not strings or lists of strings, naming the key"
  (fn []
    (throws |(fm "a: 1") "key \"a\": expected a string or a list of strings, got a number")
    (throws |(fm "x: y\nflag: true") "key \"flag\"")
    (throws |(fm "flag: true") "got a boolean")
    (throws |(fm "m:\n  k: v") "got a mapping")
    (throws |(fm "read_if:\n  - text: more") "key \"read_if\"")
    (throws |(fm "read_if:\n  - text: more") "got a mapping")
    (throws |(fm "read_if: [[a, b]]") "got a nested list")
    (throws |(fm "read_if:\n  - a\n  -") "got an empty item")
    (throws |(f/parse-doc "---\n- a\n- b\n---\n") "expected a mapping")))

(test "keeps key order, and fm-get finds values"
  (fn []
    (def d (fm "b: x\na: y\nc:\n  - x"))
    (eq (map |($ 0) d) @["b" "a" "c"])
    (eq (f/fm-get d "a") "y")
    (eq (f/fm-get d "missing") nil)
    (eq (f/fm-get nil "a") nil)))

(test "every document under .work parses"
  (fn []
    (defn markdown-under [dir]
      (def acc @[])
      (each e (sort (os/dir dir))
        (def p (string dir "/" e))
        (if (= :directory (os/stat p :mode))
          (array/concat acc (markdown-under p))
          (when (string/has-suffix? ".md" p) (array/push acc p))))
      acc)
    (def file (dyn :current-file))
    (def abs (if (string/has-prefix? "/" file) file (string (os/cwd) "/" file)))
    (def root (string (string/slice abs 0 (last (string/find-all "/" abs))) "/../../../../.work"))
    (each file (if (os/stat root) (markdown-under root) @[])
      (def [ok err] (protect (f/parse-doc (string (slurp file)))))
      (unless ok (error (string file ": " err))))))

(defn round-trips? [v list-item?]
  (def text (if list-item? (string "k:\n  - " (f/yaml-scalar v true)) (string "k: " (f/yaml-scalar v))))
  (def d (fm text))
  (deep= d (if list-item? @[@["k" @[v]]] @[@["k" v]])))

(test "written values read back unchanged"
  (fn []
    (each v ["x: y" "see # this" "`code`" "\"q\"" "'s'" "[a]" "{a}" "&a" "*a" "!t" "|" ">" "%x" "@x" "- x" "true" "null" "1.5" "42" "~"
             "it's" "a\\b" " lead" "trail " "two\nlines" "plain words" "a/b#c" "TODO"]
      (unless (round-trips? v false) (error (string "scalar " (string/format "%q" v))))
      (unless (round-trips? v true) (error (string "list item " (string/format "%q" v)))))))

(test "plain values stay unquoted"
  (fn []
    (each v ["accepted" "2026-10-25" "changing a shader" "running the bench [threads]" "crates/sim/src/rng.rs#Rng" "U-ABC"]
      (eq (f/yaml-scalar v) v)
      (eq (f/yaml-scalar v true) v))))

(when (> failures 0)
  (eprint failures " test(s) failed")
  (os/exit 1))
(print "frontmatter: all tests passed")
