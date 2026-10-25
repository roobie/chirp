# omap is linked into the binary: the type behaves like a table that remembers
# insertion order, and yaml and json carry that order through a round trip. The
# ordered JSON decoder is held to spork's own decoder on a shared corpus.
(import omap)
(import yaml)
(import spork/json)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

# Omaps do not pass deep=, so comparisons go through plain tables and arrays.
(defn- plain [x]
  (cond
    (omap/omap? x) (tabseq [[k v] :in (omap/pairs x)] k (plain v))
    (or (array? x) (tuple? x)) (map plain x)
    (or (table? x) (struct? x)) (tabseq [[k v] :pairs x] k (plain v))
    x))

(defn- type-checks []
  (def m (omap/new "b" 1 "a" 2))
  (assert (omap/omap? m) "omap?")
  (assert (not (omap/omap? @{})) "a table is not an omap")
  (assert (not (table? m)) "an omap is not a table")
  (assert (deep= @["b" "a"] (keys m)) "keys in insertion order")
  (assert (deep= @[1 2] (values m)) "values in insertion order")
  (assert (deep= @[["b" 1] ["a" 2]] (map |[;$] (pairs m))) "pairs in insertion order")
  (assert (= 2 (length m)) "length")
  (assert (= 1 (get m "b")) "get")
  (assert (= 1 (in m "b")) "in")
  (assert (= 1 (m "b")) "call")
  (assert (= :d (m "zz" :d)) "call with a default")
  (assert (nil? (get m "zz")) "absent key is nil")
  (assert (nil? (in m "zz")) "in on an absent key is nil, as on a table")
  (put m "c" 3)
  (put m "b" 9)
  (assert (deep= @["b" "a" "c"] (keys m)) "re-putting keeps the place")
  (assert (= 9 (m "b")) "re-put value")
  (put m "a" nil)
  (assert (deep= @["b" "c"] (keys m)) "nil removes")
  (assert (= 2 (length m)) "length after remove")
  (put m "a" 5)
  (assert (deep= @["b" "c" "a"] (keys m)) "a removed key re-enters last")
  (def seen @[])
  (eachp [k v] m (array/push seen [k v]))
  (assert (deep= @[["b" 9] ["c" 3] ["a" 5]] seen) "eachp")
  (assert (= "b" (next m)) "next starts at the first key")
  (assert (= "c" (next m "b")) "next")
  (assert (nil? (next m "a")) "next ends")
  (assert (= "{\"b\" 9 \"c\" 3 \"a\" 5}" (string m)) "string")
  (assert (string/find "{\"b\" 9 \"c\" 3 \"a\" 5}" (string/format "%q" m)) "%q")
  (assert (deep= @[["x" 1] ["y" 2]] (omap/pairs (omap/from-pairs [["x" 1] ["y" 2]]))) "from-pairs")
  (assert (= 1 (length (omap/new :k 1 :k 2))) "a key given twice")
  (fails |(omap/new 1) "even")
  (fails |(put (omap/new) nil 1) "nil")

  # Removing the key being visited must not derail the walk.
  (def w (omap/new ;(mapcat |[$ $] (range 20))))
  (eachk k w (put w k nil))
  (assert (= 0 (length w)) "delete while iterating")

  # Many inserts and removals, enough to compact and grow more than once.
  (def big (omap/new))
  (for i 0 5000 (put big i i))
  (for i 0 5000 (when (even? i) (put big i nil)))
  (for i 5000 8000 (put big i i))
  (assert (= 5500 (length big)) "length after churn")
  (assert (= 1 (first (keys big))) "order after churn: oldest survivor first")
  (assert (= 7999 (last (keys big))) "order after churn: newest last")
  (assert (= 4001 (big 4001)) "lookup after churn")
  (assert (nil? (big 4000)) "removed key stays removed")
  (put big 4000 :back)
  (assert (= 4000 (last (keys big)) ) "re-added key goes last"))

(def- yaml-src
  ``
  zeta: 1
  alpha:
    mid: 2
    beta: 3
  list:
    - z: 1
      a: 2
  base: &b
    x: 1
    y: 2
  derived:
    z: 0
    <<: *b
    y: 3
  gone: ~
  ``)

(defn- yaml-checks []
  (def d (yaml/decode yaml-src false false true))
  (assert (omap/omap? d) "ordered mapping")
  (assert (deep= @["zeta" "alpha" "list" "base" "derived" "gone"] (keys d)) "yaml key order")
  (assert (deep= @["mid" "beta"] (keys (d "alpha"))) "nested mapping order")
  (assert (omap/omap? (get-in d ["list" 0])) "mapping in a sequence")
  (assert (deep= @["z" "y" "x"] (keys (d "derived"))) "merged keys follow the mapping's own")
  (assert (= 3 ((d "derived") "y")) "the mapping's own key wins")
  (def text (yaml/encode d))
  (assert (< (string/find "zeta" text) (string/find "alpha" text) (string/find "list" text)) "encoded in order")
  (assert (< (string/find "mid" text) (string/find "beta" text)) "nested encoded in order")
  (assert (= (string text) (string (yaml/encode (yaml/decode text false false true)))) "round trip is stable")
  (assert (deep= (plain d) (plain (yaml/decode text false false true))) "round trip keeps the data")
  (def n (yaml/decode yaml-src true true true))
  (assert (omap/omap? n) "keywords, nils and ordered")
  (assert (not (find |(= :gone $) (keys n))) "nils leaves a null entry out")
  (assert (= 1 (n :zeta)) "keyword keys")
  (def all (yaml/decode-all "b: 1\na: 2\n---\nd: 1\nc: 2\n" false false true))
  (assert (deep= @["b" "a"] (keys (all 0))) "decode-all ordered")
  (assert (deep= @["d" "c"] (keys (all 1))) "decode-all ordered, second document")
  # Without the flag nothing changes, and tables keep their sorted encoding.
  (assert (table? (yaml/decode yaml-src)) "unflagged decode gives a table")
  (assert (string/has-prefix? "a: 1\nb: 2\n" (yaml/encode @{"b" 2 "a" 1})) "tables encode sorted")
  (assert (string/has-prefix? "b: 2\na: 1\n" (yaml/encode (omap/new "b" 2 "a" 1))) "omap encodes in order")
  (assert (string/find "k: v" (yaml/encode @[(omap/new "k" "v")])) "omap inside an array")
  (fails |(yaml/encode (omap/new (omap/new) 1)) "mapping key"))

(def- json-src
  `{"b":1,"a":{"y":[1,2,{"q":null,"p":true}],"x":"s\u00e9\ud83d\ude00"},"c":[]}`)

(defn- json-checks []
  (def d (json/decode json-src false false true))
  (assert (omap/omap? d) "ordered object")
  (assert (deep= @["b" "a" "c"] (keys d)) "json key order")
  (assert (deep= @["y" "x"] (keys (d "a"))) "nested object order")
  # Upstream writes escapes in upper case, so only that differs from the source.
  (assert (= (string/ascii-lower json-src)
             (string/ascii-lower (json/encode (json/decode json-src false false true))))
          "round trip is byte for byte")
  (def pretty (json/encode d "  " "\n"))
  (assert (deep= (plain d) (plain (json/decode pretty false false true))) "pretty round trip")
  (assert (< (string/find "\"b\"" pretty) (string/find "\"a\"" pretty)) "pretty output in order")
  (assert (= (string (json/encode (omap/new "k" @[(omap/new "n" 1) (omap/new)]) "\t"))
             (string (json/encode @{"k" @[@{"n" 1} @{}]} "\t")))
          "layout matches spork's for a single-key object")
  (def b (buffer "x"))
  (assert (= b (json/encode (omap/new "k" 1) nil nil b)) "encodes into the buffer given" )
  (assert (= "x{\"k\":1}" (string b)) "buffer result")
  # spork writes "[1," before it meets the omap; that partial write is undone.
  (def pb (buffer "x"))
  (json/encode @[1 (omap/new "k" 1)] "" "" pb)
  (assert (= "x[1,{\"k\":1}]" (string pb)) "a partial upstream write is undone")
  (fails |(json/encode @[(fn [])]) "type not supported")
  (assert (nil? ((json/decode `{"a":null,"b":1}` false true true) "a")) "nils with ordered")
  (assert (deep= @["b"] (keys (json/decode `{"a":null,"b":1}` false true true))) "a null entry is left out")
  (assert (deep= @[:b :a] (keys (json/decode `{"b":1,"a":2}` true false true))) "keywords with ordered")
  (assert (omap/omap? (json/decode (buffer `{"a":1}`) false false true)) "buffer source")
  # Without an omap, and without the flag, spork's own functions run.
  (assert (table? (json/decode `{"a":1}`)) "unflagged decode gives a table")
  (assert (= `{"a":1}` (string (json/encode @{"a" 1}))) "encode without an omap")
  (fails |(json/encode (omap/new "k" (fn []))) "type not supported")
  (fails |(json/encode (omap/new 1 2)) "object key must be a byte sequence")
  (fails |(json/encode (omap/new "k" math/inf)) "numbers must be finite")
  (fails |(json/encode (omap/new "k" "\xff")) "invalid utf-8"))

# Inputs for the parity check: the ordered decoder must give the values and the
# errors of spork's decoder, at the same position.
(def- corpus
  [``{}`` ``[]`` ``{"a":1}`` ``{"a":1,"b":2,"c":3}`` ``  { "a" : [ 1 , 2 ] }  ``
   "\t\r\n{\"a\"\n:\n1\r\n}\n"
   ``{"a":{"b":{"c":{"d":[[],[[]],{}]}}}}``
   ``[{"a":1},{"a":2},[{"a":3}]]``
   ``{"a":1,"a":2}`` ``{"":1}`` ``{"a":null}`` ``{"a":null,"b":[null,{"c":null}]}``
   ``[null,true,false]`` ``null`` ``true`` ``false``
   ``0`` ``-0`` ``1`` ``-1`` ``1.5`` ``-1.5`` ``1e3`` ``1E3`` ``1e+3`` ``1e-3`` ``-1.25e-2``
   ``123456789012345678901234567890`` ``1e308`` ``1e400`` ``-1e400`` ``0.1`` ``[0.1,0.2,0.3]``
   ``"plain"`` ``""`` ``"with space"`` ``"é"`` ``"日本語"``
   ``"\"\\\/\b\f\n\r\t"`` ``"\u0041"`` ``"\u00e9"`` ``"\u20ac"`` ``"\ud83d\ude00"``
   ``"a\u0000b"`` ``{"k\u00e9y\n":"v\u00e9"}`` ``{"\ud83d\ude00":"\ud83d\ude00"}``
   # bad input
   "" "  " ``{`` ``}`` ``[`` ``]`` ``{"a"`` ``{"a":`` ``{"a":1`` ``{"a":1,`` ``{"a":1,}``
   ``[1,]`` ``[1 2]`` ``[,1]`` ``{"a" 1}`` ``{a:1}`` ``{1:2}`` ``{"a":1 "b":2}`` ``{,}``
   ``nul`` ``nulll`` ``tru`` ``fals`` ``True`` ``NULL`` ``'a'`` ``undefined`` ``NaN`` ``Infinity``
   ``+1`` ``.5`` ``-`` ``1.`` ``0x10`` ``01`` ``--1``
   ``"unterminated`` ``"bad \x escape"`` ``"\u12"`` ``"\u12G4"`` ``"\ud83d"`` ``"\ud83dx"``
   ``"\ud83d\u0041"`` ``"\ude00"`` ``"\ud83d\"`` "\"raw\ttab\"" "\"raw\nnewline\""
   ``{} {}`` ``1 2`` ``[] x`` ``{"a":1}}`` ``{"a":[}`` ``[{]`` ``{"a":{"b":}}``
   (string "[" (string/repeat "[" 1100) (string/repeat "]" 1100) "]")
   (string/repeat "[" 2000)
   (string (string/repeat "{\"a\":" 1100) "1" (string/repeat "}" 1100))])

(defn- outcome [f]
  (def [ok v] (protect (f)))
  [ok (if ok (plain v) (string v))])

(defn- parity-checks []
  (var n 0)
  (each src corpus
    (each [kw nils] [[false false] [true false] [false true] [true true]]
      (def want (outcome |(json/decode src kw nils)))
      (def got (outcome |(json/decode src kw nils true)))
      (assert (deep= want got)
              (string/format "decoders disagree on %q (keywords %q nils %q)\nspork:   %q\nordered: %q"
                             src kw nils want got))
      (when (want 0) (++ n))))
  (assert (> n 40) "the corpus holds good inputs too")
  # The same inputs as a buffer, which upstream pads with a zero byte.
  (each src corpus
    (def want (outcome |(json/decode (buffer src))))
    (def got (outcome |(json/decode (buffer src) false false true)))
    (assert (deep= want got) (string/format "decoders disagree on buffer %q" src)))
  # A decoded document holds omaps all the way down.
  (def d (json/decode ``[{"a":{"b":1}}]`` false false true))
  (assert (omap/omap? ((d 0) "a")) "nested objects are omaps"))

(defn main [&]
  (type-checks)
  (yaml-checks)
  (json-checks)
  (parity-checks)
  (print "ok omap"))
