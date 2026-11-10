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
Review, then finalize by the owner.

## Next
- Owner finalizes after review.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- dev-proc.test.janet passes with new exit-code tests (3 for no work dir in/out of git; 1 and 2 kept elsewhere)
- commits 0e4f21d (exit code, tests) and 58c02a7 (help, SKILL.md, CHANGELOG)

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
- 2026-11-10 documented in help, SKILL.md and CHANGELOG.md
- 2026-11-10 review fixes: help wording, named-root rationale, toml/env/config tests
