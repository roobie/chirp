# Code piped to chirp runs as a script: no REPL chatter, failures in the exit status.
(defn- pipe-in
  "Spawn the binary with args, feed it code on stdin. Returns [exit stdout stderr]."
  [code & args]
  (def p (os/spawn [(dyn *executable*) ;args] :p {:in :pipe :out :pipe :err :pipe}))
  (ev/write (p :in) code)
  (:close (p :in))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string out) (string err)])

(defn- lines [s] (string/split "\n" (string/replace-all "\r" "" s)))

(defn main [&]
  # Windows may write \r\n, so compare with carriage returns removed.
  (def [code out _] (pipe-in "(print \"hi\")"))
  (assert (and (= 0 code) (deep= @["hi" ""] (lines out))) (string "piped print: " code " " (string/format "%q" out)))

  (def [ecode eout eerr] (pipe-in "(error \"boom\")"))
  (assert (not= 0 ecode) "piped error exits non-zero")
  (assert (and (empty? eout) (string/find "boom" eerr)) (string "piped error stderr: " eerr))

  (def [mcode mout _] (pipe-in "(defn main [& args] (each a args (print a)))" "-" "a" "b"))
  (assert (and (= 0 mcode) (deep= @["-" "a" "b" ""] (lines mout)))
          (string "chirp - args: " mcode " " (string/format "%q" mout)))
  (print "ok stdin"))
