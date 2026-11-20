---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-20
success_criteria:
  - dev-proc-install finds its own directory from a path with backslashes, as run.janet does
  - the linux smoke suite still passes
---

# task/smoke-backslash-path

## Purpose
A local windows smoke run reports the dev-proc-install check's real result whichever path separator the run was started with.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-4M5X7UXLRSECYKVJ dev-proc-install smoke check fails when run.janet is called with backslashes

### Why
On windows, `chirp .\test\smoke\run.janet` fails the dev-proc-install check before it tests anything: the check finds its own directory by the last `/` in its path, and a path typed with backslashes has none. CI calls the script with forward slashes, so only a local windows run shows it, and it hides a real failure of that check.

### Notes
`test/smoke/dev-proc-install.janet` `main`, the `here` binding: `(last (string/find-all "/" f))` is nil for `test\smoke\…`. `run.janet` already has a `dir-of` that takes either separator.


## Next
<!-- The cursor of the unit being worked: what is about to happen, and for a held unit the reason first.
     Rewrite it freely. A unit with open children keeps none: its present is its children. -->

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- the new split gives test\smoke\ for test\smoke\x.janet, test/smoke/ for forward slashes, .\test/smoke\ for mixed and an empty dir for a bare name, as run.janet's dir-of does
- linux-x64: test/smoke/run.janet with the released 0.13.0 binary, all checks pass, dev-proc-install included

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-20 initialized
- 2026-11-20 phase initialize → execute
- 2026-11-20 fixed: dev-proc-install splits its path on either separator
