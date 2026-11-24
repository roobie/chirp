# Run: chirp tools/build/pin.test.janet
# pin.sh reads pins.jdn with sed; this holds it to Janet's parse of the file,
# for every pin and every key.

(def- here
  (let [f (dyn :current-file)]
    (if-let [s (last (string/find-all "/" f))] (string/slice f 0 s) ".")))
(def- script (string here "/pin.sh"))
(def- pins (parse (slurp (string here "/../../pins.jdn"))))

(defn- pin-sh [& args]
  (def p (os/spawn ["sh" script ;args] :p {:out :pipe :err :pipe}))
  (def [out err] (ev/gather (ev/read (p :out) :all) (ev/read (p :err) :all)))
  [(os/proc-wait p) (string/trimr (string (or out ""))) (string (or err ""))])

(var failures 0)
(var checked 0)
(defn- check [name got want]
  (++ checked)
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(each name (sorted (keys pins))
  (def pin (pins name))
  (if (string? pin)
    (check (string name) (slice (pin-sh (string name)) 0 2) [0 pin])
    (each key (sorted (keys pin))
      (check (string name " " key) (slice (pin-sh (string name) (string key)) 0 2) [0 (pin key)]))))

# A pin or key that is not there is an error, never an empty value.
(check "unknown pin" ((pin-sh "no-such-pin") 0) 1)
(check "unknown key" ((pin-sh "janet" "no-such-key") 0) 1)
(check "key of another pin" ((pin-sh "janet" "sha256") 0) 1)
(check "no arguments" ((pin-sh) 0) 2)

(when (pos? failures)
  (eprintf "pin.sh tests: %d of %d failed" failures checked)
  (os/exit 1))
(print "pin.sh tests: ok (" checked " values)")
