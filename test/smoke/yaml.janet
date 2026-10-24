# yaml is linked into the binary: documents decode by the Core schema and encode back.
(import yaml)

(def- input ``
name: chirp
count: 0x1f
ratio: 1.5
limit: .inf
flag: no
quoted: "true"
nothing: ~
notes: |
  line one
  line two
flow: {a: 1, b: [x, y]}
list:
  - 1
  - k: v
    other: 2
base: &base
  x: 1
  y: 2
derived:
  <<: *base
  y: 3
copy: *base
``)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

(defn main [&]
  (def d (yaml/decode input))
  (assert (= "chirp" (d "name")) "string")
  (assert (= 31 (d "count")) "hex integer")
  (assert (= 1.5 (d "ratio")) "float")
  (assert (= math/inf (d "limit")) ".inf")
  (assert (= "no" (d "flag")) "no stays a string")
  (assert (= "true" (d "quoted")) "quoted true is a string")
  (assert (= :null (d "nothing")) "null is :null by default")
  (assert (= "line one\nline two\n" (d "notes")) "literal block")
  (assert (deep= @{"a" 1 "b" @["x" "y"]} (d "flow")) "flow style")
  (assert (deep= @[1 @{"k" "v" "other" 2}] (d "list")) "sequence of mappings")
  (assert (deep= @{"x" 1 "y" 2} (d "copy")) "alias")
  (assert (deep= @{"x" 1 "y" 3} (d "derived")) "merge key, explicit key wins")
  (def k (yaml/decode input true true))
  (assert (nil? (k :nothing)) "nils drops a null entry")
  (assert (= 31 (k :count)) "keyword keys")

  (def docs (yaml/decode-all "a: 1\n---\nb: 2\n"))
  (assert (deep= @[@{"a" 1} @{"b" 2}] docs) "decode-all")
  (fails |(yaml/decode "a: 1\n---\nb: 2\n") "decode-all")

  (def value @{"s" "hi" "yes" "true" "empty" "" "num" "1.5" "null" "~"
               "ml" "a\nb\n" "count" 2 "f" 0.25 "list" @[1 true @{"k" "v"}]})
  (def text (yaml/encode value))
  (assert (deep= value (yaml/decode text)) "round trip")
  (assert (string/find "count: 2\n" text) "integral numbers print without .0")
  (assert (= (string text) (string (yaml/encode (yaml/decode text)))) "stable encoding")
  (assert (= "a: 2\nb: 1\nc: 3\n" (string (yaml/encode @{:c 3 :a 2 :b 1})))
          "keys are sorted")

  # Each level refers to the one before nine times, so the last would be 9^9 nodes.
  (def bomb
    (string "a: &a [x, x, x, x, x, x, x, x, x]\n"
            (string/join
              (seq [i :range [1 9]
                    :let [n (string/from-bytes (+ 97 i)) p (string/from-bytes (+ 96 i))]]
                (string n ": &" n " [" (string/join (map (fn [_] (string "*" p)) (range 9)) ", ") "]"))
              "\n")))
  (fails |(yaml/decode bomb) "aliases expand")
  (fails |(yaml/decode "a: !custom 1\n") "!custom")
  (print "ok yaml"))
