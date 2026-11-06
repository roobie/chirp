# Run: janet tools/skillcheck/test.janet

(import ./skillcheck :as sc)

(var failures 0)
(defn check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(def canonical ".agents/skills")
(def links [".claude/skills"])
(def good-target {".claude/skills/a" "../../.agents/skills/a"})

(defn run [entries &opt targets]
  (sc/problems entries canonical links (or targets good-target)))

(def skill-a [["100644" ".agents/skills/a/SKILL.md"] ["100755" ".agents/skills/a/scripts/x.sh"]])
(def link-a ["120000" ".claude/skills/a"])

(check "link target depth" (sc/link-target ".claude/skills" canonical "a") "../../.agents/skills/a")
(check "link target depth 1" (sc/link-target ".skills" canonical "a") "../.agents/skills/a")

(check "good layout" (run [;skill-a link-a]) @[])
(check "nothing at all" (run []) @[])
(check "other paths ignored" (run [;skill-a link-a ["100644" ".claude/CLAUDE.md"]]) @[])

(check "real skill in the agent dir"
  (run [;skill-a link-a ["100644" ".claude/skills/b/SKILL.md"]])
  @[".claude/skills/b/SKILL.md: a real file in .claude/skills; put the skill in .agents/skills/b and link .claude/skills/b -> ../../.agents/skills/b"])
(check "plain file in the agent dir"
  (run [;skill-a ["100644" ".claude/skills/a"]])
  @[".claude/skills/a: not a link; make it a link -> ../../.agents/skills/a"])
(check "wrong target"
  (run [;skill-a link-a] {".claude/skills/a" "/abs/.agents/skills/a"})
  @[".claude/skills/a: links to /abs/.agents/skills/a, want ../../.agents/skills/a"])
(check "dangling link"
  (run [link-a])
  @[".claude/skills/a: links to ../../.agents/skills/a, which is not a skill in the index"])
(check "skill without a link"
  (run skill-a)
  @[".agents/skills/a: no link .claude/skills/a -> ../../.agents/skills/a"])
(check "skill without SKILL.md"
  (run [["100644" ".agents/skills/a/README.md"] link-a])
  @[".agents/skills/a: has no SKILL.md"])
(check "file directly in canonical"
  (run [;skill-a link-a ["100644" ".agents/skills/notes.md"]])
  @[".agents/skills/notes.md: a file directly in .agents/skills; skills are directories"])
(check "link inside canonical"
  (run [;skill-a link-a ["120000" ".agents/skills/a/shared"]])
  @[".agents/skills/a/shared: a link inside .agents/skills; skills there are real files"])

(if (zero? failures)
  (print "skillcheck tests: ok")
  (do (eprintf "skillcheck tests: %d failure(s)" failures) (os/exit 1)))
