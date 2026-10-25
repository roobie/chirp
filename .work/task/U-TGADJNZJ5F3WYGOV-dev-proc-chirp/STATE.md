---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-25
success_criteria:
  - The dev-proc CLI runs as `chirp .claude/skills/dev-proc/scripts/dev-proc.janet`, and no Node file remains under .claude/skills/dev-proc
  - Every command gives the same stdout, stderr, exit code and file changes as the Node version, checked side by side on a copy of this repo's .work before the Node files are removed
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
Delegating the port.

## Next
- Review the port, run the side-by-side comparison, switch hooks and SKILL.md, remove Node files, commit.

## Evidence

## Harvest
- [ ] decision: chirp's dev-proc is a fork of spartan's, ported to chirp

## Log
- 2026-10-25 initialized from B-GFASGZA3FO4XHJAV; BR chose to fork chirp's copy
- 2026-10-25 phase initialize → execute
