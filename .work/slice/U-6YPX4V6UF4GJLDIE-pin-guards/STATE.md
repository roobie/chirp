---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - rg for each pinned library version literal finds only pins.jdn, the changelog, records and test fixtures; the defines in natives.jdn resolve from the pin's :tag and a linux-x64 build with only that change is byte-identical to the one before.
  - config.jdn has :mirrors for the cli-main REPL branch, run-main and spork's json.c; a local build with a recorded hash altered fails naming the chirp file to compare and the hash to record.
  - The smoke checks assert the shape of each version, and the README table and the version docstrings name no number.
  - CI builds five targets twice with matching hashes and smoke is green on the four native runners.
---

# slice/pin-guards

## Purpose
A pinned library's version is written once, and a change in upstream code that chirp mirrors fails the build instead of waiting to be remembered (review findings 1 and 2).

## Scope
In: version defines in `natives.jdn` resolved from the pin's `:tag` by `build.janet`; `:mirrors` in `config.jdn` and its check; smoke asserts by shape; numbers out of the README table and the three `version` docstrings.
Out: listing newer upstream tags (task upstream-watch, wave C); warning flags (task c-warnings); the procedure document (task pins-skill); bringing any mirror in step with a newer upstream, which is a bump's work.

## Context & constraints
Editing `build.janet`, `config.jdn` and `natives.jdn` must not move the binary's hash when the flags they produce are the same, so the version defines are proved by an identical linux-x64 binary before the docstrings change. The JSON decoder's behaviour is already held by the parity corpus (D-ZXXSPKUCZ4IOIQPN); the mirror entry only says when to read the source. No patch touches a mirrored file. Design in the milestone's DESIGN.md (U-HM3MZPOZSVLCXGNP), findings 1 and 2.


## Next
Push with the rest of wave B; CI must build five targets twice with matching hashes and pass smoke on the four native runners. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Versions once: with only the defines changed to :pin-version keywords, linux-x64 rebuilt its objects and gave the same chirp as before (sha256 1152542d…cdac0); md4c, lexbor and pcre2 report 0.6.0, 3.0.1 and 10.49. rg for 0.2.5, 0.6.0, 3.0.1, 10.49, 1.43.0, 3.6.5 and 0.15.2 outside the changelog and .work finds only pins.jdn and cut.test.janet's fixture.
- Mirrors: with each recorded hash wrong in turn, the build stopped before compiling, e.g. 'the janet pin's src/boot/boot.janet, form (defn cli-main, is not the text that src/chirp/repl.janet was last compared with. Compare the two, bring src/chirp/repl.janet in step, then record :sha256 "e2b7183c…" …'. The three hashes equal sha256sum of boot.janet lines 5045-5250 and 4976-4989 and of spork's src/json.c at the pins. The REPL branch and run-main were read against the chirp copies at this pin; run-main's only difference is the :debug guard, which a script from stdin has no flag for.
- With the docstrings and smoke asserts changed, linux-x64 builds (sha256 571153b5…dfaf7) and all 26 smoke checks pass locally, the three version checks by shape.
- ci run 45380990270 (ed8e419): five targets built twice, every file identical in both copies; smoke green on the four native runners, the three version checks by shape; wasm job green.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
