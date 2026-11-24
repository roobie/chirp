---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - A local build with one :notices entry removed fails and names the pin that has no notice.
  - test/smoke/run.janet runs every .janet file beside it except itself; a new file runs without a list edit.
  - The three patches are a :patches list in config.jdn, each with its pin, file, reason and retiring backlog item, and the stub C source is a file build.janet reads.
  - CI builds all five targets twice with matching sha256, and each released target's NOTICES file is byte-identical to the 0.13.1 release's; the wasm one changes only by the jsec notice the guard asked for.
---

# task/build-guards

## Purpose
Make the build and the smoke driver catch the two omissions that are silent today, and move the build's remaining inline data out of build.janet (review findings 3 and 8).

## Scope
In: the notices guard in `build.janet`; `test/smoke/run.janet` listing its directory; the three patches as `:patches` in `config.jdn`; the stub C source as a file.
Out: versions from the pin's tag and the mirror check (slice pin-guards, wave B); warning flags (task c-warnings, wave C); any change to what a patch does.

## Context & constraints
Editing `build.janet` and `config.jdn` must not move the binary's hash (L-ZI52YKRRPPUHTQEI, L-2H7SFLEMCU2MPRZN), and this task changes no code that ships, so the linux-x64 binary before and after is the test. Notice sources live in `config.jdn` (D-MFWFKRO3I2W4SWIR). Design in the milestone's DESIGN.md (U-HM3MZPOZSVLCXGNP), findings 3 and 8.


## Next
Push; CI must build five targets twice with matching hashes and pass smoke on the four native runners with the listed directory (windows and macOS run it for the first time there). Compare each released target's NOTICES with 0.13.1's. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- linux-x64 built locally before and after the change gives the same chirp (sha256 1152542d…cdac0) and the same NOTICES.txt (0c154cd3…4347, also the 0.13.1 release's NOTICES-linux-x64.txt); the log shows the three patches read from :patches and found already applied.
- With the tomlin entry removed from :notices the build stops in 0.3 s: 'linux-x64 carries the tomlin pin, but :notices in tools/build/config.jdn has no entry for it on this target; its license text would not ship'.
- The guard found a real gap on its first wasm run: jsec's Janet modules are in the image on every target, but its notice was :openssl true, so chirp.wasm shipped without jsec's license text. The notice now applies to every target; wasm's NOTICES.txt gains the jsec section, the others are unchanged.
- test/smoke/run.janet lists its directory: the locally built linux-x64 runs the same 26 checks as the old hand list, all passing. wasm32-wasi built locally with the stub prelude read from tools/build/stub-prelude.c passes test/wasm/smoke.mjs.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] learning: jsec's Janet source is in every target's image, so a notice tied to linking OpenSSL misses the wasm build; the notices guard counts :janet-sources pins for every target

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
