#!/usr/bin/env chirp
# Run: chirp find.test.janet   (exits non-zero on failure)
(import ./find)

(var failures 0)

(defn test [name thunk]
  (def r (protect (thunk)))
  (unless (r 0)
    (++ failures)
    (eprint "FAIL " name ": " (string (r 1)))))

(defn eq [actual expected]
  (unless (deep= actual expected)
    (error (string "expected " (string/format "%q" expected) " got " (string/format "%q" actual)))))

(defn rec [id title &opt read-if]
  {:id id :kind "decision" :title title :read-if (or read-if [])})
(defn ids [hits] (map |($ :id) hits))

# Filler records so that a word in one record is rare.
(def filler (seq [i :range [0 12]] (rec (string/format "D-FILL%02d" i) (string "Filler " i) ["unrelated work"])))

(def corpus
  [(rec "D-SHADER" "Shaders are authored in Slang" ["adding or changing a shader" "crates/view/src/dots.slang"])
   (rec "L-WGSL" "Slang output is machine-shaped" ["debugging a shader or reading generated WGSL"])
   (rec "D-COLOR" "Colors are blended in gamma space" ["changing the color palette" "adding translucent overlays"])
   (rec "L-MORALE" "Fight outcomes are noisy without morale" ["writing an outcome test"])
   ;filler])

(test "finds records by stemmed words"
  (fn []
    (eq (ids (find/find-records corpus "shaders")) @["D-SHADER" "L-WGSL"])
    (eq (ids (find/find-records corpus "blending")) @["D-COLOR"])
    (eq (ids (find/find-records corpus "colors")) @["D-COLOR"])))

(test "a cue hit outranks a title-only hit"
  (fn []
    (def hits (find/find-records corpus "shader"))
    (eq (ids hits) @["D-SHADER" "L-WGSL"])
    (def hits2 (find/find-records corpus "morale outcome"))
    (eq ((first hits2) :id) "L-MORALE")
    (eq ((first hits2) :cues) @["writing an outcome test"])
    (assert (> ((first hits2) :score) 0))))

(test "records matching more query words rank first"
  (fn []
    (def hits (find/find-records corpus "debugging a shader"))
    (eq ((first hits) :id) "L-WGSL")
    (eq ((first hits) :matched) @["debugging" "shader"])))

(test "ref-style cues are neither matched nor reported"
  (fn []
    (def hits (find/find-records corpus "dots"))
    (eq hits @[])
    (def hits2 (find/find-records corpus "slang"))
    (assert (all (fn [h] (not (some |(string/find "/" $) (h :cues)))) hits2))))

(test "FTS syntax in the query is inert"
  (fn []
    (eq (find/find-records corpus "foo\" OR *") @[])
    (eq (find/find-records corpus "shader\" OR \"") (find/find-records corpus "shader"))
    (eq (find/find-records corpus "NEAR(a b) AND NOT -x ^y") @[])
    (eq (find/find-records corpus "col*") @[])))

(test "no match, empty and punctuation-only queries"
  (fn []
    (eq (find/find-records corpus "xyzzy") @[])
    (eq (find/find-records corpus "") @[])
    (eq (find/find-records corpus "  ?! -- ") @[])))

(test "no records"
  (fn [] (eq (find/find-records @[] "anything") @[])))

(when (> failures 0)
  (eprint failures " test(s) failed")
  (os/exit 1))
(print "find: all tests passed")
