---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-13
success_criteria:
  - status --json --detail gives every unit in the tree success_criteria and gate, in the same shape as status <unit> --json
  - status --json without --detail is unchanged
  - tests cover it, the dev-proc suite passes, and the skill and changelog say so
---

# task/status-detail-criteria

## Purpose
dert's Gates view needs every open unit's success criteria and gate from one status --json --detail run; today only status <unit> --json carries them, so dert would run dev-proc once per unit.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

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
- 2026-11-13 initialized
- 2026-11-13 phase initialize → execute
