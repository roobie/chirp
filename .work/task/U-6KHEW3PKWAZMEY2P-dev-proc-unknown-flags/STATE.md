---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - Every dev-proc command given a flag it does not accept exits non-zero, and stderr names that flag and the command's valid flags
  - Every flag documented in HELP is still accepted by its command, shown by the existing dev-proc tests passing
  - A test in dev-proc.test.janet runs a command with an unknown flag and checks the exit code and the message
---

# task/dev-proc-unknown-flags

## Purpose
TODO: why this unit exists, in one or two sentences.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-IPLFSODIGG5YM6EW dev-proc fails on an unknown flag instead of ignoring it

### Why
`parse-args` in .agents/skills/dev-proc/scripts/dev-proc.janet takes any `--key value` pair and no command checks the keys it was given. So a mistyped or made-up flag is silently dropped and the command succeeds. In a skelly drive session, `record … --section "Why=…"` (a flag that does not exist; the real ones are `--body` and `--body-file`) created about 20 decisions, learnings and backlog items whose sections held only TODO placeholders. Nothing warned, and the lost text had to be recovered from the session transcript. An agent working from memory will invent plausible flags, so an unknown flag must be an error that names the valid ones, the way an unknown heading already is.

### Notes
- Each command already knows its options from HELP. One table of the flags each command accepts, checked in `parse-args` or in the dispatch, would cover them all.
- A test should run one command with an unknown flag and expect a non-zero exit, with stderr naming the flag.
- This is related to B-HFEHNNAUWFDXTAMQ (Janet's cli-main exits 0 on an unknown flag), but this gap is dev-proc's own parser and is fixable here.


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
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
