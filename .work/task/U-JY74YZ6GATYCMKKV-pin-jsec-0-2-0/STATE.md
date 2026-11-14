---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-14
success_criteria:
  - pins.jdn pins jsec at 9b57288eaf2c65d9aedbde1864a0f4a14cde41e5 and linux-x64 and windows-x64 builds succeed with both jsec patches applied
  - the spork-https overlay no longer rewrites :ca; fix-tls and its doc suffix are gone
  - 'a smoke check shows :ca trusts only that CA: the private-CA server is trusted and a publicly trusted host is refused'
  - test/smoke/run.janet and the CI checks pass on the built binary
  - L-CPIUGJI6EY2HEID2 is superseded or removed, and CHANGELOG notes the :ca behaviour change
---

# task/pin-jsec-0-2-0

## Purpose
Move the jsec pin to its 0.2.0 development branch (9b57288e), where clients honour :ca as the only trust anchor (llmII/jsec#1). Today chirp's overlay maps :ca onto the additive :security {:ca-file}, so a request meant to trust only a private CA also accepts any publicly trusted cert.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


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
- 2026-11-14 initialized
- 2026-11-14 phase initialize → execute
