# Run: janet tools/leakcheck/test.janet

(import ./leakcheck :as lc)

(def rules (parse (slurp "tools/leakcheck/rules.jdn")))
(def env {"HOME" "/srv/alice-home" "USER" "alice" "PATH" "/usr/bin"
          "MY_API_TOKEN" "s3cr3t-value-123" "SHORT_TOKEN" "abc"})
(def needles (lc/build-needles rules env "box1.example.org"))

(var failures 0)
(defn rules-of [text] (map |($ :rule) (lc/scan-text text needles)))
(defn check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(check "generic home path" (rules-of "see /home/carol/x") @["home-path"])
(check "macOS home path" (rules-of "at /Users/carol") @["home-path"])
(check "user inside home path also flagged" (rules-of "/home/alice") @["home-path" "host-user"])
(check "home inside URL ignored" (rules-of "https://x.org/home/page") @[])
(check "tilde path" (rules-of "open ~/notes today") @["tilde-path"])
(check "bare tilde ignored" (rules-of "about ~5 / ~ /") @[])
(check "windows home" (rules-of `C:\Users\bob\file`) @["windows-home"])
(check "host home" (rules-of "cd /srv/alice-home/src") @["host-home"])
(check "user as word" (rules-of "owner alice here") @["host-user"])
(check "user inside word ignored" (rules-of "malice aliceson") @[])
(check "hostname and short name" (rules-of "box1 and box1.example.org") @["host-name" "host-name" "host-name"])
(check "secret env name" (rules-of "GH_TOKEN=$MY_API_TOKEN") @["env-secret-name"])
(check "secret env value" (rules-of "key s3cr3t-value-123") @["env-secret-value"])
(check "short secret value ignored" (rules-of "abc") @[])
(check "non-secret env ignored" (rules-of "PATH /usr/bin") @[])
(check "binary skipped" (rules-of "/home/carol\0") @[])

(def f (first (lc/scan-text "x\n  ~/notes" needles)))
(check "line number" (f :line) 2)
(check "matched text" (f :text) "~/notes")
(check "secret flagged" ((first (lc/scan-text "s3cr3t-value-123" needles)) :secret) true)

(def allow [{:path "docs/" :rule "tilde-path"} {:path "a.md" :text "/home/alice"}])
(check "allow by dir prefix and rule" (lc/allowed? allow "docs/x.md" {:rule "tilde-path" :text "~/a"}) true)
(check "allow rule must match" (lc/allowed? allow "docs/x.md" {:rule "home-path" :text "~/a"}) false)
(check "allow exact path and text" (lc/allowed? allow "a.md" {:rule "home-path" :text "/home/alice"}) true)
(check "allow exact path only" (lc/allowed? allow "b/a.md" {:rule "home-path" :text "/home/alice"}) false)

(if (zero? failures)
  (print "leakcheck tests: ok")
  (do (eprintf "leakcheck tests: %d failure(s)" failures) (os/exit 1)))
