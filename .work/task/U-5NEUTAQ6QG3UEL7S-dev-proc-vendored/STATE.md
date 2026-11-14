---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-15
success_criteria:
  - the skill under .agents/skills/dev-proc is a copy written by the owner's vendor sync, and its own design records are no longer kept here
  - AGENTS.md says the copy is vendored and where changes go; tests, leakcheck and dev-proc check pass
---

# task/dev-proc-vendored

## Purpose
dev-proc's canonical home moved to the owner's private tools repo; chirp keeps a one-way vendored copy for public users.

## Scope
In: the vendor sync of .agents/skills/dev-proc, removing the records about dev-proc's own design (they moved upstream with their ids), a decision and an AGENTS.md note, and a backlog item for an installer guard.
Out: the installer, the site page and the tests, which stay as they are because public users install the skill through chirp.

## Context & constraints
The upstream repo is private, so nothing committed here may name its host, its users or any local path. leakcheck enforces that. Records here that mention moved ids keep working by id.


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
- 2026-11-15 initialized
- 2026-11-15 phase initialize → execute
