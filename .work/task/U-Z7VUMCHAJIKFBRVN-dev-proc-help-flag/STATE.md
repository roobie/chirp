---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - 'Every dev-proc command given --help (and -h where find and report take it today) prints usage and exits 0: the command''s own usage where it has one, the main HELP otherwise'
  - An unknown flag is still a usage error (exit 2), and the flag tables' consistency test still passes
  - A test in dev-proc.test.janet covers --help on a command with its own usage and on one without
---

# task/dev-proc-help-flag

## Purpose
TODO: why this unit exists, in one or two sentences.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-NYH6ZSXTHFNZJI42 Make --help print usage for every dev-proc command

### Why
Since unknown flags became usage errors, `<cmd> --help` exits 2 on every command but find and report, which print their own usage. Someone typing `--help` wants usage, not an error.

### Notes
- Accept `help` for every command (like ENV-OPTIONS), printing the command's own usage where it has one and HELP otherwise.


## Now
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- every command's --help exits 0 and prints its :help or the main HELP; new test covers find, report -h, note, status; all suites green

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
- 2026-11-11 help is a COMMON-FLAGS entry; COMMANDS entries may carry :help; dispatch prints it; -h counts only as the sole argument
