---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-01
success_criteria:
  - dev-proc note <unit> log -- "--force was needed" writes the text as given; a test covers it
  - dev-proc help and the changelog mention --
---

# task/note-terminator

## Purpose
A -- argument ends dev-proc's flag parsing, so note text (or any positional) can start with --.

## Scope
In: `--` in dev-proc's parse-args, its help line, a test, a changelog entry.
Out: other CLIs.

## Context & constraints
parse-args is shared by every dev-proc command, so `--` applies to all of them.

### Origin
Promoted from backlog: B-DDPZPOA7SAX5D6LX dev-proc parse-args: a -- terminator so note text can start with --

### Why
`note <unit> log "--force was needed"` reads the text as a flag, so a note about a flag can't be written as the user typed it. Found while building `note` in slice dev-proc-ergonomics.

### Notes
- The usual fix is `--` ending flag parsing, as in most CLIs.


## Now
Change, test, help line and changelog done; committing.

## Next
- Finalize and close

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- dev-proc.test.janet: 'note preserves text beginning with -- after the terminator' fails on the HEAD dev-proc.janet (a note needs text) and passes with the change; all dev-proc tests pass.
- $DP help lists -- with the note example; $DP note task/note-terminator log -- "--force …" wrote the text as given.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-01 initialized
- 2026-11-01 phase initialize → execute
- 2026-11-01 -- ends flag parsing in parse-args; help line, test, changelog
