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
In: success_criteria and gate on every unit of status --json --detail; skill, changelog, help.
Out: any change to status --json without --detail.

## Context & constraints
The gate is computed in memory from loaded units, so --detail adds no reads against the run's byte budget.


## Now
Implemented and tested; awaiting review and finalize.

## Next
- Review, then finalize.

## Evidence
- `chirp dev-proc.test.janet` in .agents/skills/dev-proc/scripts: all tests passed, including the new test comparing each --detail unit with `status <unit> --json` and checking plain status lacks the fields.

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
- 2026-11-13 --detail carries success_criteria and gate via shared unit-criteria and unit-gate
