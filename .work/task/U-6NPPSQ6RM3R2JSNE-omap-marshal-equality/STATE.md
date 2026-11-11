---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - An omap survives marshal/unmarshal with its keys, values and order intact, shown by a smoke check, including sending one to another ev thread
  - Two omaps with the same entries in the same order compare equal by content (with deep= if Janet's abstract hooks allow, otherwise a documented omap function), shown by a smoke check
  - The guard against printing a self-containing omap is per thread, not one process-wide counter
  - All four targets still build twice with matching sha256 (or, locally, linux-x64 builds and every smoke check passes)
---

# task/omap-marshal-equality

## Purpose
TODO: why this unit exists, in one or two sentences.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-6LSXCQXV5LOOALKI omap marshal, deep= by content, and a per-thread print guard

### Why
An omap cannot be marshalled, so it cannot be sent to another ev thread or saved in an image. `deep=` compares two omaps by identity, so tests have to convert them first. The guard against printing a map that holds itself is one process-wide counter, which threads printing at the same time could confuse.

### Notes
Janet abstract types can supply marshal and unmarshal callbacks; `deep=` has no hook for abstracts, so content equality may need an `omap/equal?`.


## Now
builds twice and runs the wasm build, then hands back

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- smoke omap.janet: marshal round trip incl. self-holding map, shared and equal-but-separate maps; another ev thread receives an omap; omap/equal? by content; four threads print self-holding maps. linux-x64 smoke: all checks passed

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: omap equality is the function omap/equal?, not the type's compare/hash callbacks, because Janet's marshaller (seen table) and tables treat compare-equal values as one: two separate equal omaps came back from a marshal as one aliased map (verified). So = and deep= stay identity.
- [ ] learning: Janet 1.43 deep= has no abstract hook; it falls to = which calls the type's compare; a compare hook also makes hash content-based, which conflates mutable keys in marshal
- [ ] learning: JANET_THREAD_LOCAL (janet.h) gives a per-thread static, __thread under gcc/clang, empty when single-threaded (wasm); needs no -fms-extensions

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
