---
phase: initialize
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - A .work/-only push to a branch shows a green ci run with checks run and build, compare, smoke and wasm skipped.
  - The same on main leaves pages green with nothing deployed, and the site still serves the last built commit.
  - A code push, a new branch and a release dry run still build everything.
  - A decision records the trade, and the owner has confirmed that a run with skipped jobs satisfies main's branch rules.
---

# task/ci-work-only

## Purpose
A push that changes only .work/ gets a green ci run that built nothing, in place of ten cold builds (review finding 4; wanted by BR, 2026-11-24).

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Next
<!-- The cursor of the unit being worked: what is about to happen, and for a held unit the reason first.
     Rewrite it freely. A unit with open children keeps none: its present is its children. -->

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
