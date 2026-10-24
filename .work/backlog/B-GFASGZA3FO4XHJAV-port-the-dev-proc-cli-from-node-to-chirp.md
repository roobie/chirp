---
created: 2026-10-25
---

# B-GFASGZA3FO4XHJAV Port the dev-proc CLI from Node to chirp

## Why
The repo exists to make chirp the default scripting runtime. Yet its own process tool runs on Node, the very kind of extra install chirp argues against (BR, 2026-10-25). Porting it is dogfooding: every gap it hits is feedback on what chirp lacks.

## Notes
- Scope: `.claude/skills/dev-proc/scripts/`, about 830 lines of Node (dev-proc, find, frontmatter) plus about 280 lines of tests.
- Behaviour to keep: the CLI commands, the restricted-YAML front matter, the `$DP check` ref checks, git trailer lookups for `dig`, and the commit hooks.
- The tests have to come along too, written in Janet and run by chirp.
- The skill text (`DP=...`, the hooks) must point at the new entry point in the same commit.
- Open question: whether dev-proc is shared with other repos. If it is, the port changes what they need installed too.
