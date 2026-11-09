---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-09
success_criteria:
  - a `surprises` help topic covers the verified core surprises, each with a way around it and an example that asserts the behaviour
  - the help-examples smoke check runs the examples of tasks and surprises on every native runner
---

# task/janet-surprises

## Purpose
Core behaviour that differs from other languages cost time porting dev-proc; documenting it is chirp's side (D-MNNDC6PNBUNZXT7O).

## Scope
In: src/chirp/help/surprises.md; the FTS5 stopword note in the sqlite topic; generalising the tasks smoke check to help-examples.
Out: changing core behaviour.

## Context & constraints
All claims re-verified on 0.10.0-dev (Janet 1.43.0).

### Origin
Promoted from backlog: B-QTVDOIIJDDZC3XDE A help topic on Janet core surprises met porting dev-proc

### Why
Porting dev-proc from Node (B-IRERZRV2753OHW3R) hit core behaviour that cost time because nothing pointed it out. A chirp help topic, or a short section in an existing one, would save the next script author the same hunt. chirp does not patch Janet's core (D-MNNDC6PNBUNZXT7O), so documenting is chirp's side; any fix is upstream's.

### Notes
- `sort` and `sort-by` are not stable.
- `peg/replace-all` returns a buffer, which `os/spawn` rejects as an argument.
- `ev/read … :all` returns nil on empty output.
- There is no mktemp; spork/sh has `create-dirs` for recursive mkdir.
- FTS5 ships no stopword list (dev-proc carries its own in .agents/skills/dev-proc/scripts/find.janet).
- Checked on 0.9.0: `string/trim` keeps NUL and `string/join` returns a string, so those two from the old list were dropped.
- Already covered elsewhere and dropped from the old list: os/spawn's `:cd` and `:e` (src/chirp/help/subprocess.md, L-6VTNLI3CGMKSPBNU) and ordered JSON and YAML (D-PYFZFKJPCW3QPOTB).


## Now
Committing.

## Next
- CI, finalize; then B-TNLZ

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- linux-x64 build: help-examples runs 38 examples (tasks 29, surprises 9), smoke passes; queries 'sort stable', 'compare tables', 'unicode length' list the surprises section first; site builds help/surprises.html.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-09 initialized
- 2026-11-09 phase initialize → execute
