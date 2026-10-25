---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-25
success_criteria:
  - The dev-proc CLI runs as `chirp .claude/skills/dev-proc/scripts/dev-proc.janet`, and no Node file remains under .claude/skills/dev-proc
  - Every command except find gives the same stdout, stderr, exit code and file changes as the Node version, checked side by side on a copy of this repo's .work before the Node files are removed
  - find keeps its output format and ranks with SQLite FTS5; its tests show the right records found, cue hits ranked above title-only hits, and query text that cannot inject FTS syntax
  - The tests are ported to Janet, run by chirp, and pass
  - The tracked commit hooks, SKILL.md and every `DP=` line call the chirp entry point, and a commit through the hooks still gets checked
  - Each chirp gap met along the way is filed as a usage-feedback issue or recorded with the reason it was not
---

# task/dev-proc-chirp

## Purpose
chirp's own process tool runs on Node, the kind of extra install chirp argues against. Porting it to chirp removes Node from the repo's workflow and puts chirp under daily use.

## Scope
In: `.claude/skills/dev-proc/scripts/` (dev-proc, find, frontmatter and their tests) rewritten in Janet; the tracked hooks and SKILL.md pointed at it.
Out: the copies in other repos (spartan, twc, kvx, agent-caveman), which keep Node; new dev-proc features or behaviour changes.

## Context & constraints
- BR chose to fork chirp's copy (2026-10-25). All five copies were identical (sha256 7995ba52…); spartan holds the upstream. Behaviour must stay the same, so the copy can be offered back to spartan later.
- Hooks are tracked and call each check themselves (D-U5B6PF3E3RVNDWFL). They currently skip dev-proc when node is absent; after the port they need chirp instead.
- chirp feedback rule: friction becomes a `usage-feedback` issue on roobie/chirp, but BR has said not to file GitHub issues for now, so gaps go into Harvest until that changes.

### Origin
Promoted from backlog: B-GFASGZA3FO4XHJAV Port the dev-proc CLI from Node to chirp

### Why
The repo exists to make chirp the default scripting runtime. Yet its own process tool runs on Node, the very kind of extra install chirp argues against (BR, 2026-10-25). Porting it is dogfooding: every gap it hits is feedback on what chirp lacks.

## Now
Port landed; Node files removed; hooks and SKILL.md call chirp.

## Next
- Finalize: harvest, close.

## Evidence
- Side-by-side harness (scratchpad, not committed) on clones of this repo's .work: readonly 63, mutating 91, records 24, history 25, messages 31, hooks 8, nested 23 steps, 0 differing. Normalised: `node`/`.mjs` in hook text, Node's quoting of template items that are not valid YAML, Node's stack trace on an unhandled error (chirp prints one line).
- `chirp frontmatter.test.janet`, `find.test.janet`, `dev-proc.test.janet`: all pass. `$DP check` ok on all 65 front matters.
- find on this repo: same top hits as Node for hooks, dev-proc port, xxhash, release version; FTS5 differs (by design) on "optimising the build" and "random rng".
- Malformed front matter now reports libyaml's error, not the old wording; `__proto__` and an orphan `- item` are accepted, a list item starting `[` is rejected.
- This commit went through the chirp hooks.

## Harvest
- [ ] decision: chirp's dev-proc is a fork of spartan's, ported to chirp
- [ ] decision: front matter is real YAML read by chirp's yaml module; values must be strings or lists of strings, and dev-proc quotes what it writes (BR, 2026-10-25). Other repos' files show why the type check matters: twc criteria with `: ` decode as mappings
- [ ] decision: find ranks with SQLite FTS5 instead of its own stemmer and scoring (BR, 2026-10-25)
- [ ] backlog: yaml/decode loses key order; frontmatter.janet recovers it by scanning the text. An ordered decode would remove that
- [ ] backlog: chirp gaps met in the port, not filed (BR: no issues for now): os/spawn has no cwd and its env table doubles as stdio; no recursive mkdir or mktemp; no ordered JSON object; FTS5 ships no stopword list

## Log
- 2026-10-25 initialized from B-GFASGZA3FO4XHJAV; BR chose to fork chirp's copy
- 2026-10-25 phase initialize → execute
