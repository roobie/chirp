---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-09
success_criteria:
  - '`chirp --help read modules` lists all 54 bundled modules, generated at build time from chirp.jdn :modules, TLS ones included'
  - the chirp topic points at it instead of the module/cache command, and a smoke check asserts the count
---

# task/module-list

## Purpose
The documented way to list bundled modules prints 45 of 54: TLS modules are loaded on first require and are not in module/cache at start.

## Scope
In: a generated `modules` help topic; the chirp topic's section; a smoke assertion.
Out: a runtime API listing modules.

## Context & constraints
Extra topics (stem -> markdown) already reach help/collect (the changelog). The TLS deferral must stay: a start without TLS must not export the OS store.

### Origin
Promoted from backlog: B-E5VQW2FRGTVEN5PB Listing bundled modules in chirp.md misses the TLS modules

### Why
`chirp --help read chirp` lists bundled modules with `(keys module/cache)`, but jsec/* and spork-https are loaded on first require (so the OS trust store is exported only when needed) and are not in the cache at start: the command prints 45 of 54.

### Notes
- Fix the command (e.g. include the :chirp-tls path entry's names) or expose the list some other way; `help/tasks.md` already names all 54 by goal.


## Now
Committing; CI with the next push.

## Next
- smoke, CHANGELOG, finalize; then B-QTVD and B-TNLZ

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- linux-x64 build: --help read modules lists 54 (jsec/*, spork-https included); -h lists the topic; help smoke asserts the TLS entries and spork/json's goal; full smoke passes. 'bundled modules' query: tasks, then chirp/listing-bundled-modules (which points at it), modules 4th.

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
