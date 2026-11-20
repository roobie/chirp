---
phase: finalize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-20
success_criteria:
  - Using a bundled module's function without its import (crypto/digest) errors with the working import line in scripts, -e and the REPL; other unknown symbols keep Janet's error; smoke suite passes on a fresh build
---

# task/symbol-hint

## Purpose
Issue #22: an unknown symbol from a bundled module should point at the import that provides it, as #8 does for imports

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Next
<!-- The cursor of the unit being worked: what is about to happen, and for a held unit the reason first.
     Rewrite it freely. A unit with open children keeps none: its present is its children. -->

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Built linux-x64 from this branch; smoke suite (absolute binary path): all checks passed incl. import-hint. crypto/digest via -e, script file and stdin shows the jsec/crypto hint.

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
- 2026-11-20 phase execute → finalize
