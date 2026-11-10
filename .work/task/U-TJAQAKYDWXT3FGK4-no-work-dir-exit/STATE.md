---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-10
success_criteria:
  - A command that needs a work dir and finds none exits 3, in a git repo and outside one, with nothing on stdout and the stderr message unchanged
  - No other path exits 3; unknown unit, bad args and check failures keep their codes
  - dev-proc help, SKILL.md and CHANGELOG.md document the code
---

# task/no-work-dir-exit

## Purpose
A program scanning many directories with status --json must tell a directory with no dev-proc work from a dev-proc failure without matching an error sentence, which a reword would break. Give that case its own exit code.

## Scope
In: a named exit code for the no-work-dir error of every command that needs a root; help, SKILL.md, CHANGELOG.md; tests.
Out: any JSON on stdout for that case; rewording the stderr message; the codes other failures use.

## Context & constraints
Codes in use: 1 failure, 2 usage error. Nothing else is distinct, so 3 is the lowest free one.


## Now
Adding the exit code and its tests.

## Next
- Docs, then review.

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
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
