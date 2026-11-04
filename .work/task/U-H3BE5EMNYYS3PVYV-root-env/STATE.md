---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-04
success_criteria:
  - DEV_PROC_ROOT=<dir> acts as --root <dir> for every command, in and out of git; --root on the command line wins
  - the env-to-option mapping is one table, so a later global option gets its DEV_PROC_ variable by adding one entry
  - tests, help, SKILL.md and CHANGELOG cover it; a decision supersedes D-QXMTO5IDSCYSUDTD
---

# task/root-env

## Purpose
Let a directory carry dev-proc's static options (first --root) through the environment, so direnv or a shell can pin them per directory, in or out of a git repo.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
Code, tests, docs done; finalize next.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- ENV-OPTIONS + env-defaults in dev-proc.janet fill args from DEV_PROC_<NAME> before any command runs; init honours --root; a missing --root/DEV_PROC_ROOT dir is named in the error
- test 'DEV_PROC_ROOT is the default for --root, in and out of a git repo' (init, new, status, --root wins, git repo, relative refused); dev-proc, find, frontmatter suites pass
- help, SKILL.md Pinned options bullet, CHANGELOG

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: an environment variable is the default for each global option, superseding D-QXMTO5IDSCYSUDTD's no-env stance

## Log
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
