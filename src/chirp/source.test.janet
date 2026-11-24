# Run: chirp src/chirp/source.test.janet
# The locator that turns a binding's :source-map into its definition's text.
(import ./source)
(import spork/sh)

(var failures 0)
(defn- check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/chirp-source-test-" (os/getpid) "-" (os/time)))
(sh/create-dirs (string tmp "/out/src/lib"))
(sh/create-dirs (string tmp "/repo/src"))
(defer (sh/rm tmp)
  (spit (string tmp "/out/src/lib/a.janet")
        "(def x 1)\n\n(defn f\n  \"doc\"\n  [y]\n  (+ x y))\n(def broken (\n")
  # CRLF upstream files are shown with LF.
  (spit (string tmp "/out/src/lib/b.janet") "(defn g []\r\n  1)\r\n")
  (spit (string tmp "/repo/src/n.c")
        "#include <janet.h>\n\nJANET_FN(fn_a, \"(a)\", \"doc\") {\n    if (argc) {\n    }\n    return janet_wrap_nil();\n}\n\nJANET_FN(open_ended, \"(b)\", \"doc\") {\n")

  (def locate
    (source/locator [{:prefix "src/lib/" :dir "src/lib/" :show "lib/"}
                     {:prefix "./src/" :base :repo :dir "src/" :show "chirp/"}
                     {:prefix "whole.janet" :dir "src/lib/a.janet" :show "lib/a.janet"}]
                    {:out (string tmp "/out/") :repo (string tmp "/repo/")}))

  (check "a janet form from its line and column"
         (locate ["src/lib/a.janet" 3 1])
         ["(defn f\n  \"doc\"\n  [y]\n  (+ x y))" "lib/a.janet:3"])
  (check "a one-line form" (locate ["src/lib/a.janet" 1 1]) ["(def x 1)" "lib/a.janet:1"])
  (check "CRLF becomes LF" (locate ["src/lib/b.janet" 1 1]) ["(defn g []\n  1)" "lib/b.janet:1"])
  (check "a form that never closes has no source" (locate ["src/lib/a.janet" 7 1]) nil)
  (check "a C function runs to the first line that is only }"
         (locate ["./src/n.c" 3 1])
         ["JANET_FN(fn_a, \"(a)\", \"doc\") {\n    if (argc) {\n    }\n    return janet_wrap_nil();\n}"
          "chirp/n.c:3"])
  (check "a C function with no closing line has no source" (locate ["./src/n.c" 9 1]) nil)
  (check "a rule whose prefix is the whole name" (locate ["whole.janet" 1 1]) ["(def x 1)" "lib/a.janet:1"])
  (check "no rule matches" (locate ["elsewhere/a.janet" 1 1]) nil)
  (check "the file is missing" (locate ["src/lib/missing.janet" 1 1]) nil)
  (check "a line past the end" (locate ["src/lib/a.janet" 99 1]) nil)
  (each bad [nil "src/lib/a.janet" ["src/lib/a.janet" 1] ["src/lib/a.janet" 0 1]
             ["src/lib/a.janet" 1 0] [:file 1 1] ["src/lib/a.janet" 1.5 1]]
    (check (string/format "a source-map that is not [file line col]: %q" bad) (locate bad) nil)))

(when (pos? failures)
  (eprintf "source tests: %d failed" failures)
  (os/exit 1))
(print "source tests: ok")
