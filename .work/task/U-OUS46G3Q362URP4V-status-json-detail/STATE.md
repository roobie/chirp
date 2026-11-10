---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-10
success_criteria:
  - status <unit> --json carries the unit's sections (comments stripped), structured harvest items and awaiting
  - status --json carries awaiting per unit and, per record, the date fields and needs/priority/created, with --detail adding record sections
  - Existing fields keep their names and shapes; tests cover every new field; the dev-proc tests and skillcheck pass
---

# task/status-json-detail

## Purpose
A read-only viewer (dert) must show every checkout's dev-proc state through the CLI's JSON alone. status --json lacks a unit's sections, harvest items, the owner-wait flags and backlog metadata, so a unit page, board and inbox cannot be built from it.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
Done: sections, harvest, awaiting, record fields, status <record>, --detail; tests, SKILL.md, changelog. Left: review and finalize.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- dev-proc.test.janet, find.test.janet, frontmatter.test.janet, skillcheck tests and `dev-proc check` pass; status --json --detail on agentic-tools' work dir parses (4 units, 92 records).

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: detail is default on status <unit|record> --json and opt-in (--detail) in the tree; records get generic front matter passthrough
- [ ] learning: the 24 vs 21 backlog count could not be reproduced; status and status --json share one record list

## Log
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
- 2026-11-10 implemented the JSON extension
- 2026-11-10 SKILL.md and changelog describe the new JSON
