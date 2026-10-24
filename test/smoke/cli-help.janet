# -h/--help print chirp's entry points first, then Janet's own option list.
(defn- run [& args]
  (def p (os/spawn [(dyn *executable*) ;args] :p {:out :pipe :err :pipe}))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn main [&]
  (each flag ["-h" "--help"]
    (def [code raw err] (run flag))
    (def out (string/replace-all "\r" "" raw))
    (assert (= 0 code) (string flag ": exit " code " " err))
    (def mine (string/find "chirp help" out))
    (def theirs (string/find "Options are:" out))
    (assert (and mine (string/find "self-update" out) theirs)
            (string flag ": missing parts in " out))
    (assert (< mine theirs) (string flag ": chirp's part must come first"))
    (assert (not (string/find "```" out)) (string flag ": markdown fence leaked")))
  (print "ok cli-help"))
