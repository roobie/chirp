# The baked-in help answers offline: ranked search, reads, and clean failures.
(defn- help [& args]
  (def p (os/spawn [(dyn *executable*) "help" ;args] :p {:out :pipe :err :pipe}))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn main [&]
  (def [qcode qout _] (help "query" "sqlite"))
  (assert (= 0 qcode) "query exits 0")
  (assert (string/find "sqlite/" qout) (string "query hit: " qout))

  (def [rcode rout _] (help "read" "chirp"))
  (assert (and (= 0 rcode) (string/find "# chirp" rout)) "read prints the file")

  (def [dcode dout _] (help "read" "spork-https/get"))
  (assert (and (= 0 dcode) (string/find "chirp adds" dout)) "read prints a docstring")

  (def [bcode bout berr] (help "query" "\""))
  (assert (not= 0 bcode) "malformed query fails")
  (assert (and (empty? bout) (not (string/find "error:" berr))) "no stack trace")

  (def [ucode _ _] (help "read" "no-such-id"))
  (assert (not= 0 ucode) "unknown id fails")

  (def [ncode nout _] (help "query" "zzzqqqxxx"))
  (assert (and (= 0 ncode) (string/find "no matches" nout)) "no hits exits 0")
  (print "ok help"))
