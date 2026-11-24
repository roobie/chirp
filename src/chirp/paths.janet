# The OS test and the path helpers that chirp's own modules share, so there is
# one of each. src/tar/tar.janet keeps its own: it is a public module and takes
# nothing from chirp's internals.

(defn windows?
  "Whether this is windows, however Janet was compiled for it. A function, so
  the answer is the running binary's and not the image builder's."
  []
  (truthy? (index-of (os/which) [:windows :mingw])))

(defn dir-of
  "The directory part of path, without a trailing separator: \".\" when path
  names no directory and \"/\" when it is directly under the root. A backslash
  separates too on windows, where a path may mix both."
  [path]
  (def back? (windows?))
  (var cut nil)
  (for i 0 (length path)
    (def c (path i))
    (when (or (= c (chr "/")) (and back? (= c (chr "\\")))) (set cut i)))
  (cond (nil? cut) "."
        (zero? cut) "/"
        (string/slice path 0 cut)))

(defn source-dir
  "The directory of the file being compiled, with a trailing slash. For reading
  a file that lies beside the source while the image is built."
  []
  (string (dir-of (dyn *current-file*)) "/"))
