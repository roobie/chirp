---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - <dir>/.dev-proc.toml work_dir names <dir>'s work dir for status, new, init, find, check, hooks and trailers; subdirectories are unaffected; no file means .work
  - work_dir must be one path segment and the only key; a bad file is an error naming it
  - check warns about a leftover .work beside a renamed one; a git-ignored .dev-proc.toml is ignored, with a warning
  - dig finds a record or unit by id anywhere in the repo's history, so a rename does not hide older deletions
  - tests, SKILL.md, help and CHANGELOG cover it
---

# slice/work-dir-name

## Purpose
A committed .dev-proc.toml with work_dir = "<name>" renames the work dir of the directory it sits in, for every clone; without the file nothing changes.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-A6P3Z5V64HCGCOIZ dev-proc: a team-wide name for the .work dir

### Why
dev-proc.root (git config) covers a personal dir with any name. If a team wants every clone to use a name other than `.work`, that takes a committed setting that discovery (nearest-root, all-roots) reads. Not built: nobody has asked for it yet.

### Notes
TODO


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
