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
  # The first hit is the https topic's section, whose markdown has `:trusted-cert`.
  (def [_ cout _] (help "query" "trusting certificate" "--limit" "1"))
  (assert (and (string/find "trusted-cert" cout) (not (string/find "`" cout)) (not (string/find "\x02" cout)))
          (string "query snippets are plain text: " cout))

  # FTS5 would read the punctuation as syntax; the name is searched as a phrase.
  (each [q hit] [["spork-https" "spork-https/"] ["self-update" "self-update"] ["dev-proc" "dev-proc"]]
    (def [hcode hout herr] (help "query" q))
    (assert (and (= 0 hcode) (string/find hit hout)) (string "hyphenated query " q ": " hcode " " hout herr)))
  # A binding's name lists that binding first.
  (each q ["os/spawn" "spork/getline/make-getline" "table?"]
    (def [hcode hout herr] (help "query" q))
    (assert (and (= 0 hcode) (string/has-prefix? (string q "  ") hout))
            (string "query " q ": " hcode " " hout herr)))
  (def [ccode cout cerr] (help "query" "os/spawn :cd"))
  (assert (and (= 0 ccode) (string/find "subprocess/" cout)) (string "query os/spawn :cd: " ccode " " cout cerr))
  (def [tcode tout terr] (help "query" "title:server"))
  (assert (and (= 0 tcode) (string/find "server" tout)) (string "column filter: " tcode " " tout terr))

  # A goal in a user's words lands on the tasks topic first: the goals of
  # issues #4 (a table), #6 (validation) and #8 (json).
  (each [q want] [["print a table" "tasks/print-a-table"]
                  ["validate data" "tasks/validate-data-against-a-schema"]
                  ["json" "tasks/read-and-write-json"]
                  ["import json" "tasks/read-and-write-json"]]
    (def [gcode gout gerr] (help "query" q "--limit" "1"))
    (assert (and (= 0 gcode) (string/has-prefix? (string want "  ") gout))
            (string "goal query " q ": " gcode " " gout gerr)))
  (def [_ tout _] (help "read" "tasks"))
  (assert (string/find "## Print a table" tout) "read tasks prints the topic")

  (def [scode sout _] (help "query" "subprocess working directory"))
  (assert (and (= 0 scode) (string/find "subprocess/run-in-another-directory" sout))
          (string "subprocess query: " sout))

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

  # The module list is generated, so it holds the TLS modules, which a listing
  # of module/cache at start would miss.
  (def [mcode mout _] (help "read" "modules"))
  (def listed (length (string/find-all "\n- `" mout)))
  (assert (and (= 0 mcode) (>= listed 50) (string/find "- `jsec/tls`: " mout)
               (string/find "- `spork-https`: " mout) (string/find "- `spork/json`: Read and write JSON" mout))
          (string "read modules: " listed " listed\n" mout))

  # An overlay's docstring replaces upstream's in the help (#9).
  (def [tcode tout _] (help "read" "spork/tarray/new"))
  (assert (and (= 0 tcode) (string/find "offset counts bytes" tout)) (string "tarray/new docs: " tout))

  (def [ncode nout _] (help "query" "zzzqqqxxx"))
  (assert (and (= 0 ncode) (string/find "no matches" nout)) "no hits exits 0")
  (print "ok help"))
