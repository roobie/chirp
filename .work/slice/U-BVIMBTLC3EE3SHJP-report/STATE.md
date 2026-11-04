---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - dev-proc report [<range>] [--since <date>] [--json] summarises units (delivered, scrapped, open, with type/name, commit count and parent) and record counts (+added −removed per kind)
  - with no range it covers the last tag..HEAD, or all history when there is no tag
  - everything comes from git; no new state is stored; dig and report share how paths are recognised
  - tests, SKILL.md, help and CHANGELOG cover it
---

# slice/report

## Purpose
Give the operator a short overview of the dev-proc work done over a stretch of git history: which units were delivered, scrapped or left open, how many commits each took, and the records harvested.

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
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
