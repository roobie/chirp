# The REPL edits lines: history recall and cursor movement work at the prompt.
# It needs a terminal, so util-linux script gives it one; elsewhere this check
# has nothing to drive and passes.

(defn- script-available []
  (and (= :linux (os/which))
       (= 0 (os/execute ["script" "--version"] :p {:out (file/open "/dev/null" :w)}))))

(defn- quote-sh [s] (string "'" (string/replace-all "'" "'\\''" s) "'"))

(defn- session
  "Run the REPL in a terminal of `cols` columns (0: size unset), typing each
  of `keys` once the next prompt shows. Returns [exit output]."
  [cols keys]
  (def cmd (string (if (pos? cols) (string "stty cols " cols " rows 24; ") "")
                   "exec " (quote-sh (dyn *executable*))))
  (def p (os/spawn ["script" "-qec" cmd "/dev/null"] :pe
                   (merge (os/environ) {"TERM" "xterm" "NO_COLOR" "1" :in :pipe :out :pipe})))
  (def seen @"")
  # Keys go only after the prompt they answer: typed earlier, the terminal is
  # still in line mode and turns Enter into a newline the editor ignores.
  (defn await [text]
    (def got (protect (ev/with-deadline 20
                        (while (not (string/find text seen))
                          (def chunk (ev/read (p :out) 4096))
                          (unless chunk (error "output ended"))
                          (buffer/push seen chunk)))))
    (unless (first got)
      (os/proc-kill p)
      (error (string "no " (describe text) " from the REPL (" (last got) "): " (describe seen)))))
  (eachp [i k] keys
    (await (string "repl:" (inc i) ":> "))
    (ev/write (p :in) k))
  (:close (p :in))
  [(ev/with-deadline 20 (os/proc-wait p)) (string/replace-all "\r" "" seen)])

(defn main [&]
  (unless (script-available)
    (print "ok repl (skipped: no util-linux script)")
    (os/exit 0))
  # Up recalls (+ 20 22); three lefts put the cursor before 22, so 1 makes 122.
  (def [code out] (session 100 ["(+ 20 22)\r" "\e[A\e[D\e[D\e[D1\r" "\x04"]))
  (assert (and (= 0 code) (string/find "\n42" out) (string/find "\n142" out))
          (string "edited line: exit " code ": " (describe out)))
  # With no width to draw in, the line is read plainly rather than failing.
  (def [ncode nout] (session 0 ["(+ 20 22)\r" "\x04"]))
  (assert (and (= 0 ncode) (string/find "\n42" nout)) (string "unsized terminal: exit " ncode ": " (describe nout)))
  (print "ok repl"))
