# Tests for paths.janet. Run: chirp src/chirp/paths.test.janet
(import ./paths)

(var failed 0)
(defn- check [what got want]
  (unless (deep= got want)
    (++ failed)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" what got want)))

(def win (paths/windows?))
(check "windows? agrees with os/which" win (truthy? (index-of (os/which) [:windows :mingw])))

(each [path want]
  [["a/b/c.txt" "a/b"]
   ["a/b/" "a/b"]
   ["c.txt" "."]
   ["" "."]
   ["/c.txt" "/"]
   ["/a/c.txt" "/a"]
   ["./c.txt" "."]
   # A backslash is an ordinary character except on windows.
   ["a\\b/c.txt" "a\\b"]
   ["a/b\\c.txt" (if win "a/b" "a")]
   ["a\\c.txt" (if win "a" ".")]
   ["C:\\Users\\x/chirp/ca.pem" "C:\\Users\\x/chirp"]]
  (check (string "dir-of " path) (paths/dir-of path) want))

(check "source-dir ends in a slash and holds this file"
       (truthy? (os/stat (string (paths/source-dir) "paths.test.janet"))) true)
(check "source-dir of a bare file name"
       (with-dyns [*current-file* "x.janet"] (paths/source-dir)) "./")

(if (pos? failed)
  (do (eprintf "paths tests: %d failed" failed) (os/exit 1))
  (print "ok paths tests"))
