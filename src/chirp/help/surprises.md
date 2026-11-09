# Surprises: Janet behaviour that trips up scripts

Behaviour of Janet's core, and of a few bundled modules, that costs time when you expect what other languages do. chirp does not change Janet's core, so each section gives the way around it. Every example asserts the behaviour it describes, and chirp's tests run them, so this page fails the build if a newer Janet changes one.

## sort and sort-by are not stable

Elements that compare equal can come out in any order, not the order they went in. To keep that order, sort on the key plus the original position:

```janet
(def rows [[:b 1] [:a 2] [:b 3] [:a 4] [:b 5] [:a 6] [:b 7] [:a 8]])
(def stable
  (map last (sort-by |[(first (last $)) (first $)]
                     (seq [[i r] :pairs rows] [i r]))))
(assert (deep= stable @[[:a 2] [:a 4] [:a 6] [:a 8] [:b 1] [:b 3] [:b 5] [:b 7]]))
(print "stable order kept")
```

## Program arguments must be strings, not buffers

`os/execute` and `os/spawn` reject a buffer in the argument list with "bad slot #1, expected string". `slurp`, `buffer`, `peg/replace-all` and `ev/read` all return buffers. Wrap them in `string`:

```janet
(def code (peg/replace-all "N" "1" "(print N)"))
(assert (buffer? code))
(def [ok err] (protect (os/execute [(dyn *executable*) "-e" code] :p)))
(assert (and (not ok) (string/find "expected string" err)))
(assert (= 0 (os/execute [(dyn *executable*) "-e" (string code)] :p)))
```

## ev/read with :all returns nil when nothing was written

Reading a child's output with `(ev/read (p :out) :all)` gives `nil`, not an empty buffer, when the program printed nothing. `(string x)` turns either into a string:

```janet
(def p (os/spawn [(dyn *executable*) "-e" "nil"] :p {:out :pipe}))
(def out (ev/read (p :out) :all))
(os/proc-wait p)
(assert (nil? out))
(assert (= "" (string out)))
```

## os/mkdir makes one directory

`os/mkdir` raises when a parent is missing and returns false when the directory exists. `sh/create-dirs` from `spork/sh` makes every missing parent, like `mkdir -p`. There is no function for a temporary directory: build a unique name under `TMPDIR` (`TEMP` on windows):

```janet
(import spork/sh)

(def tmp (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") ".")
                 "/surprises-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
(assert (not (first (protect (os/mkdir (string tmp "/a/b"))))))
(sh/create-dirs (string tmp "/a/b"))
(assert (false? (os/mkdir (string tmp "/a"))))
(sh/rm tmp)
```

## A table cannot hold nil

`(put t k nil)` removes `k`, and a struct or table literal drops keys whose value is nil. To record "known but empty", store a value such as `:null` or `false`:

```janet
(def t @{:a 1 :b nil})
(assert (= 1 (length t)))
(put t :a nil)
(assert (empty? t))
```

## = compares tables and arrays by identity

`=` is true for two tables, arrays or buffers only when they are the same object. `deep=` compares contents. Structs, tuples and strings are values, so `=` compares those by content:

```janet
(assert (not (= @{:a 1} @{:a 1})))
(assert (deep= @{:a 1} @{:a 1}))
(assert (= {:a 1} {:a 1}))
(assert (= [1 2] [1 2]))
```

## get returns nil, in raises

`(get xs i)` returns nil, or a default you pass, for an index or key that is not there. `(in xs i)` raises for an array index out of range. Use `get` when absence is normal:

```janet
(def xs @[1 2])
(assert (nil? (get xs 5)))
(assert (= :none (get xs 5 :none)))
(assert (not (first (protect (in xs 5)))))
```

## length counts bytes, not characters

Strings are bytes, so `length` of a non-ASCII (Unicode) string is more than its characters, and `string/slice` can cut a character in half. `utf8/decode-rune` from `spork/utf8` reads one code point and its width in bytes, so counting characters is a walk:

```janet
(import spork/utf8)

(defn chars [s]
  (var [n at] [0 0])
  (while (< at (length s))
    (+= at (last (utf8/decode-rune s at)))
    (++ n))
  n)
(assert (= 6 (length "naïve")))
(assert (= 5 (chars "naïve")))
```

## The path of the running chirp

To run chirp again from a script, use `(dyn *executable*)`. `sh/self-exe` from `spork/sh` can return nil on windows:

```janet
(def exe (dyn *executable*))
(assert (string? exe))
(assert (= 0 (os/execute [exe "-e" "(os/exit 0)"] :p)))
```
