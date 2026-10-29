# The changelog is baked in: printed by --changelog and searchable as a help topic.
(defn- run [& args]
  (def p (os/spawn [(dyn *executable*) ;args] :p {:out :pipe :err :pipe}))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn main [&]
  (def [code out err] (run "--changelog"))
  (assert (and (= 0 code) (string/find "# Changelog" out))
          (string "--changelog: " code " " err))

  # A release must carry its own section; a -dev build from main has not been
  # released yet, so its changes are under Unreleased.
  (def [_ ver _] (run "-v"))
  (def version (first (peg/match ~(* "chirp " (<- (some (if-not " " 1)))) ver)))
  (def heading (if (string/find "-" version) "## Unreleased" (string "## " version)))
  (assert (string/find (string "\n" heading "\n") (string/replace-all "\r" "" out))
          (string "no " heading " section for " version))

  (def [rcode rout rerr] (run "--help" "read" "changelog/0-1-0"))
  (assert (and (= 0 rcode) (string/find "## 0.1.0" rout)) (string "read section: " rerr))

  (def [qcode qout _] (run "--help" "query" "changelog"))
  (assert (and (= 0 qcode) (string/find "changelog" qout)) (string "query: " qout))
  (print "ok changelog"))
