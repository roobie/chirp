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
In: the jsec pin, the overlay's :ca mapping (fix-tls) and its doc suffix, a hermetic smoke check of :ca exclusivity, the learning, help, README and CHANGELOG.
Out: the User-Agent half of the overlay (stays), the two jsec build patches (still needed), moving to a tagged 0.2.0 (none exists yet).

## Context & constraints
- 9b57288e is the tip of jsec's 0.2.0 branch; there is no 0.2.0 tag yet, so the pin carries no :tag.
- Its source tree keeps the dirs natives.jdn compiles (two new files land in src/jutils, which is globbed), project.janet only adds sanitizer and toolchain targets and a Janet >= 1.41.1 floor (chirp pins 1.43.0), and it still has no LICENSE, so the notice in tools/build/notices stays (D-BPDFOMM2OH7HMPZB).
- :trusted-cert and :security {:ca-file} stay additive on 0.2.0; only :ca is exclusive.


## Now
overlay keeps only the User-Agent fix; building linux-x64 and windows-x64 while the smoke check learns exclusivity

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
- [ ] backlog: move the jsec pin to the tagged 0.2.0 release (with :tag) once llmII/jsec tags it

## Log
- 2026-11-14 initialized
- 2026-11-14 phase initialize → execute
- 2026-11-14 jsec pin moved to 9b57288e (0.2.0 branch tip); source list, flags and LICENSE status checked against 08a92f6
- 2026-11-14 fix-tls and its doc suffix removed; https help, README and CHANGELOG say :ca now trusts only that CA
