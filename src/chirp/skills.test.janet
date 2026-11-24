# Run: chirp src/chirp/skills.test.janet
# What the skill installer writes, links, leaves and refuses, in directories of
# its own. test/smoke/dev-proc-install.janet runs the shipped command.
(import ./skills)
(import spork/sh)

(var failures 0)
(defn- check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

# Links need a privilege on Windows that a test cannot count on.
(when (index-of (os/which) [:windows :mingw])
  (print "skills tests: skipped on windows")
  (os/exit 0))

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/chirp-skills-test-" (os/getpid) "-" (os/time)))
(def conf {:canonical ".agents/skills" :links [".claude/skills"]})
(def files [["SKILL.md" "# demo\n"] ["scripts/run.janet" "(print 1)\n"]])

(var n 0)
(defn- fresh
  "A new empty base directory."
  []
  (def base (string tmp "/" (++ n)))
  (sh/create-dirs base)
  base)

(defn- install
  "Install into base with flags. Returns [ok output]."
  [base & flags]
  (def out @"")
  (def ok (with-dyns [:out out :err out]
            (skills/install-skill (merge {:base base} (struct ;(mapcat |[$ true] flags)))
                                  "demo" files conf)))
  [(truthy? ok) (string out)])

(defn- read [& parts] (let [[ok text] (protect (slurp (string ;parts)))] (when ok (string text))))

(sh/create-dirs tmp)
(defer (sh/rm tmp)
  # collect: sorted, nested, minus the excluded suffixes.
  (let [src (fresh)]
    (sh/create-dirs (string src "/scripts"))
    (spit (string src "/SKILL.md") "s")
    (spit (string src "/scripts/b.janet") "b")
    (spit (string src "/scripts/b.test.janet") "t")
    (spit (string src "/scripts/a.janet") "a")
    (check "collect" (skills/collect src [".test.janet"])
           @[["SKILL.md" "s"] ["scripts/a.janet" "a"] ["scripts/b.janet" "b"]])
    (check "collect refuses a directory with nothing to ship"
           (first (protect (skills/collect (string src "/scripts") [".janet"]))) false))

  # A first install writes the canonical copy and links the agent dir to it.
  (let [base (fresh)
        [ok out] (install base)]
    (check "first install succeeds" ok true)
    (check "the canonical copy holds the files"
           [(read base "/.agents/skills/demo/SKILL.md") (read base "/.agents/skills/demo/scripts/run.janet")]
           ["# demo\n" "(print 1)\n"])
    (check "the agent dir is a link" (os/lstat (string base "/.claude/skills/demo") :mode) :link)
    (check "the link is relative, so the tree can move"
           (os/readlink (string base "/.claude/skills/demo")) "../../.agents/skills/demo")
    (check "the link reaches the files" (read base "/.claude/skills/demo/SKILL.md") "# demo\n")
    (def [ok2 out2] (install base))
    (check "a second install changes nothing" [ok2 (truthy? (string/find "up to date" out2))] [true true]))

  # An edited shipped file is kept unless --force; files not shipped are never touched.
  (let [base (fresh)]
    (install base)
    (spit (string base "/.agents/skills/demo/SKILL.md") "edited\n")
    (spit (string base "/.agents/skills/demo/mine.txt") "mine\n")
    (def [ok out] (install base))
    (check "an edit is refused" [ok (truthy? (string/find "refused" out))] [false true])
    (check "and kept" (read base "/.agents/skills/demo/SKILL.md") "edited\n")
    (def [ok2 _] (install base :force))
    (check "--force rewrites it" [ok2 (read base "/.agents/skills/demo/SKILL.md")] [true "# demo\n"])
    (check "a file the skill does not ship stays" (read base "/.agents/skills/demo/mine.txt") "mine\n"))

  # --copy writes real copies into the agent dirs and no canonical copy.
  (let [base (fresh)
        [ok _] (install base :copy)]
    (check "--copy succeeds" ok true)
    (check "--copy writes a directory, not a link" (os/lstat (string base "/.claude/skills/demo") :mode) :directory)
    (check "--copy writes no canonical copy" (os/stat (string base "/.agents/skills/demo")) nil))

  # Something else already at the agent dir's place is left alone.
  (let [base (fresh)]
    (sh/create-dirs (string base "/.claude/skills/demo"))
    (spit (string base "/.claude/skills/demo/theirs.txt") "theirs\n")
    (def [ok out] (install base))
    (check "a foreign directory is skipped" [ok (truthy? (string/find "skipped" out))] [false true])
    (check "and untouched" (read base "/.claude/skills/demo/theirs.txt") "theirs\n")
    (check "the canonical copy is still written" (read base "/.agents/skills/demo/SKILL.md") "# demo\n"))

  # A link at the skill dir leads into someone's checkout: never written through,
  # with or without --force (D-TKUKHE7T3TSZWWSD).
  (let [base (fresh)
        checkout (fresh)]
    (spit (string checkout "/SKILL.md") "the checkout's own\n")
    (sh/create-dirs (string base "/.agents/skills"))
    (os/symlink checkout (string base "/.agents/skills/demo"))
    (def [ok out] (install base :force))
    (check "a linked skill dir is refused" [ok (truthy? (string/find "refused" out))] [false true])
    (check "the checkout is untouched" (read checkout "/SKILL.md") "the checkout's own\n")
    (check "nothing was added to the checkout" (os/stat (string checkout "/scripts")) nil))

  # A link above the skill dir leads out of the base as well (issue 20): refused
  # at either level, forced or not, before anything is written or linked.
  (each [above made] [[".agents" nil] [".agents/skills" ".agents"]]
    (let [base (fresh)
          store (fresh)]
      (sh/create-dirs (string store "/demo"))
      (spit (string store "/demo/SKILL.md") "the store's own\n")
      (spit (string store "/skills-marker") "")
      (when made (sh/create-dirs (string base "/" made)))
      # .agents -> a store that holds skills/demo; .agents/skills -> one that holds demo.
      (if made
        (os/symlink store (string base "/" above))
        (do (sh/create-dirs (string store "/skills/demo"))
          (spit (string store "/skills/demo/SKILL.md") "the store's own\n")
          (os/symlink store (string base "/" above))))
      (each flags [[] [:force]]
        (def [ok out] (install base ;flags))
        (check (string "a linked " above " is refused " (if (empty? flags) "" "with --force"))
               [ok (truthy? (string/find (string "refused: " above ", which") out))] [false true]))
      (check (string "nothing is written through a linked " above)
             (read store (if made "/demo/SKILL.md" "/skills/demo/SKILL.md")) "the store's own\n")
      (check (string "no agent dir is made beside a refused " above)
             (os/lstat (string base "/.claude")) nil)))

  # --copy writes into the agent dirs, so a link above one of those is refused too.
  (let [base (fresh)
        store (fresh)]
    (os/symlink store (string base "/.claude"))
    (def [ok out] (install base :copy :force))
    (check "--copy refuses a linked agent parent"
           [ok (truthy? (string/find "refused: .claude, which" out))] [false true])
    (check "and writes nothing through it" (os/stat (string store "/skills")) nil))

  # The agent dir's parent may be a link to the canonical parent: a layout this
  # repo uses. Nothing is written through it, so it is accepted.
  (let [base (fresh)]
    (sh/create-dirs (string base "/.agents/skills"))
    (sh/create-dirs (string base "/.claude"))
    (os/symlink "../.agents/skills" (string base "/.claude/skills"))
    (def [ok out] (install base))
    (check "agent parent linked to the canonical parent" ok true)
    (check "and the canonical copy is real" (os/lstat (string base "/.agents/skills/demo") :mode) :directory)))

(when (pos? failures)
  (eprintf "skills tests: %d failed" failures)
  (os/exit 1))
(print "skills tests: ok")
