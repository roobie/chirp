---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-14
success_criteria:
  - 'the STATE.md template has ## Next and no ## Now; note takes next but not now, which is a usage error naming next and log'
  - note <unit> next on a unit with open children is refused
  - 'check warns on a ## Now section in any unit, and on a non-empty ## Next in a unit with open children'
  - SKILL.md, site docs and CHANGELOG describe the rule; the dev-proc tests pass, new cases included
---

# task/leaf-cursor

## Purpose
A hand-kept cursor on a parent repeats what its open children already say, and it drifts; only the unit being worked keeps one, and Now folds into Next and Log

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
- 2026-11-14 initialized
- 2026-11-14 phase initialize → execute
