# Run: chirp src/chirp/help.test.janet
# How help text becomes entries, and how a query in a user's words finds them.
(import ./help)
(import sqlite3)
(import spork/sh)

(var failures 0)
(defn- check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))
(defn- fails [name f needle]
  (def [ok err] (protect (f)))
  (unless (and (not ok) (string/find needle (string err)))
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want an error holding: %s" name [ok err] needle)))

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/chirp-help-test-" (os/getpid) "-" (os/time)))
(sh/create-dirs tmp)
(def dir (string tmp "/"))

(def topic
  (string "# Serving HTTPS\n\nIntro with `code`.\n\n"
          "## Certificates and keys\n\nA certificate is needed.\n\n"
          "```janet\n## not a heading, a comment in code\n(print 1)\n```\n\n"
          "## Working directory :cd\n\nRuns in a directory.\n"))

(def modules
  {"mod" @{'f @{:doc "(mod/f x)\n\nFrobnicates x." :source-map ["m.janet" 1 1]}
           'hidden @{:doc "private" :private true}
           'undocumented @{:value 1}
           'other/g @{:doc "an import, not mod's own"}}})

(defer (sh/rm tmp)
  (spit (string dir "https.md") topic)
  (spit (string dir "notes.txt") "not markdown, not a topic")
  (def entries
    (help/collect dir modules {"extra" "# Extra topic\n\nBody.\n"}
                  (fn [sm] (when sm ["(defn f [x] x)" "m.janet:1"]))))
  (def by-id (tabseq [e :in entries] (e :id) e))

  (check "entries are sorted by id" (map |($ :id) entries) (sorted (map |($ :id) entries)))
  (check "a topic, and a section per ## heading with a slug id"
         (filter |(or (string/has-prefix? "https" $) (= "extra" $)) (map |($ :id) entries))
         @["extra" "https" "https/certificates-and-keys" "https/working-directory-cd"])
  (check "the topic's title is its h1" (get-in by-id ["https" :title]) "Serving HTTPS")
  (check "the topic's kind" (get-in by-id ["https" :kind]) :topic)
  (check "the topic's text is the whole file" (get-in by-id ["https" :text]) (string/trim topic))
  (check "a ## inside a code fence stays in its section"
         (truthy? (string/find "## not a heading" (get-in by-id ["https/certificates-and-keys" :body])))
         true)
  (check "the indexed text has no markdown syntax"
         (string/find "`" (get-in by-id ["https" :plain])) nil)
  (check "a documented public binding is an entry" (get-in by-id ["mod/f" :kind]) :doc)
  (check "its title is the docstring's first line" (get-in by-id ["mod/f" :title]) "(mod/f x)")
  (check "its source comes from the locator"
         [(get-in by-id ["mod/f" :source]) (get-in by-id ["mod/f" :source-at])]
         ["(defn f [x] x)" "m.janet:1"])
  (check "private, undocumented and imported bindings are left out"
         (filter |(string/has-prefix? "mod/" $) (map |($ :id) entries)) @["mod/f"])
  (check "Janet's core is documented too" (get-in by-id ["os/spawn" :kind]) :doc)

  (fails "a topic named like a bundled module"
         |(help/collect dir modules {"mod" "# Mod\n"}) "shadows a bundled module")
  (fails "two entries with one id"
         |(help/collect dir {} {"dup" "# D\n\n## Same\n\na\n\n## Same\n\nb\n"}) "duplicate help id")

  (def db (help/index entries))
  (defer (sqlite3/close db)
    (defn ids [q &opt limit]
      (def [ok rows] (help/search db q (or limit 5)))
      (if ok (map |($ :id) rows) [:invalid rows]))
    (check "the stemmer finds a plural from the singular"
           (first (ids "certificate")) "https/certificates-and-keys")
    (check "a name with a slash is a phrase, and its own entry ranks first"
           (first (ids "os/spawn")) "os/spawn")
    (check "a name with a hyphen is a phrase, not a column filter"
           (first (ids "string/has-prefix?")) "string/has-prefix?")
    (check "a leading colon is punctuation" (first (ids ":cd")) "https/working-directory-cd")
    (check "a column filter still works" (first (ids "title:serving")) "https")
    (check "a quoted phrase passes as it is" (first (ids `"certificate is needed"`)) "https/certificates-and-keys")
    (check "nothing matches" (ids "zzzzqqqq") @[])
    (check "an invalid query is reported, not thrown" (first (ids `AND AND`)) :invalid)
    (check "the limit holds" (length (ids "string" 3)) 3)
    (def [_ rows] (help/search db "certificate" 1 ["<b>" "</b>"]))
    (check "marks surround the matched term"
           (truthy? (string/find "<b>certificate</b>" ((first rows) :s))) true))

  # An entry's boost moves it above another of the same relevance.
  (def twins [{:id "a/plain" :kind :section :title "Frobnicate" :body "frobnicate the widget"}
              {:id "z/boosted" :kind :section :title "Frobnicate" :body "frobnicate the widget" :boost 1.5}])
  (def db2 (help/index twins))
  (defer (sqlite3/close db2)
    (def [_ rows] (help/search db2 "frobnicate" 5))
    (check "a boosted entry ranks first" (map |($ :id) rows) @["z/boosted" "a/plain"])))

(when (pos? failures)
  (eprintf "help tests: %d failed" failures)
  (os/exit 1))
(print "help tests: ok")
