# tomlin is bundled: a TOML file parses into Janet data.
(import tomlin)

(def- input ``
title = "chirp"
count = 42
ratio = 1.5

[owner]
name = "wren"
tags = ["a", "b"]

[[nest]]
egg = 1

[[nest]]
egg = 2
``)

(defn main [&]
  (def dir (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") "."))
  (def path (string dir "/chirp-smoke-" (os/time) "-" (math/floor (* 1e6 (math/random))) ".toml"))
  (spit path input)
  (def parsed
    (defer (os/rm path)
      (tomlin/toml->janet (slurp path))))
  (assert (not (os/stat path)) "input file is deleted")
  (assert (= "chirp" (parsed :title)) "string")
  # Integers come back as int/s64, which = does not equate with numbers.
  (assert (compare= 42 (parsed :count)) "integer")
  (assert (= 1.5 (parsed :ratio)) "float")
  (assert (= "wren" (get-in parsed [:owner :name])) "nested table")
  (assert (deep= @["a" "b"] (get-in parsed [:owner :tags])) "array")
  (assert (= 2 (length (parsed :nest))) "array of tables")
  (assert (compare= 2 (get-in parsed [:nest 1 :egg])) "array of tables value")
  (print "ok toml " (length (keys parsed)) " keys"))
