# The baked-in help answers offline: ranked search, reads, and clean failures.
(defn- help [& args]
  (def p (os/spawn [(dyn *executable*) "--help" ;args] :p {:out :pipe :err :pipe}))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn main [&]
  (def [ucode uout _] (help))
  (assert (and (= 0 ucode) (string/find "chirp --help query" uout)
               (string/find "  sqlite  SQLite" uout) (string/find "Options are:" uout))
          "bare --help shows usage, topics and Janet's options")

  (def [kcode kout _] (help "read" "help"))
  (assert (and (= 0 kcode) (string/find "NEAR(" kout)) "the help topic holds query examples")

  (def [xcode xout xerr] (help "bogus"))
  (assert (= 2 xcode) "unknown word exits 2")
  (assert (and (empty? xout) (string/find "bogus" xerr) (not (string/find "Options are:" xerr)))
          "unknown word is named on stderr, nothing else printed")

  (def [qcode qout _] (help "query" "sqlite"))
  (assert (= 0 qcode) "query exits 0")
  (assert (string/find "sqlite/" qout) (string "query hit: " qout))

  (def [rcode rout _] (help "read" "chirp"))
  (assert (and (= 0 rcode) (string/find "# chirp" rout)) "read prints the file")

  (def [dcode dout _] (help "read" "spork-https/get"))
  (assert (and (= 0 dcode) (string/find "chirp adds" dout)) "read prints a docstring")

  # --source adds the definition after the docstring; without it nothing changes.
  (defn- lf [s] (string/replace-all "\r" "" s))
  (def [pcode pout _] (help "read" "default-peg-grammar" "--source"))
  (assert (and (= 0 pcode) (string/find "\n(def default-peg-grammar" (lf pout))
               (string/find "boot.janet:" pout))
          "--source prints a Janet core definition with its file:line")
  (def [_ plain _] (help "read" "default-peg-grammar"))
  (assert (and (string/find "The default grammar" plain) (not (string/find "(def default-peg-grammar" plain))
               (not (string/find "boot.janet" plain)))
          "without --source there is no source")
  (assert (= (lf plain) (lf (string/slice pout 0 (length plain)))) "--source only appends")
  (def [_ sout _] (help "read" "--source" "os/spawn"))
  (assert (and (string/find "JANET_CORE_FN(os_spawn" sout) (string/find "os.c:" sout))
          "--source prints a core C function, the flag in any position")
  (def [_ xout _] (help "read" "spork/sh/exec-slurp" "--source"))
  (assert (and (string/find "(defn exec-slurp" xout) (string/find "sh.janet:" xout))
          "--source prints a spork definition")
  (def [tcode tout _] (help "read" "chirp" "--source"))
  (assert (and (= 0 tcode) (= (lf tout) (lf rout))) "a topic has no source")

  (def [bcode bout berr] (help "query" "\""))
  (assert (not= 0 bcode) "malformed query fails")
  (assert (and (empty? bout) (not (string/find "error:" berr))) "no stack trace")

  (def [ucode _ _] (help "read" "no-such-id"))
  (assert (not= 0 ucode) "unknown id fails")

  (def [ncode nout _] (help "query" "zzzqqqxxx"))
  (assert (and (= 0 ncode) (string/find "no matches" nout)) "no hits exits 0")
  (print "ok help"))
