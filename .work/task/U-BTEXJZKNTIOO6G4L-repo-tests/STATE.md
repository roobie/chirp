---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - chirp tools/test.janet finds and runs every *.test.janet in the repo, the vendored dev-proc tests included, and passes from a checkout with an installed chirp in under 30 seconds.
  - Tests beside update.janet, help.janet, skills.janet and source.janet cover version order, sums parsing, trust resolution, section splitting, the query grammar, relative paths and install differences; a deliberately broken version comparison fails the driver.
  - The CI job is named checks, does not need the build job, runs a released linux-x64 chirp fetched from a :chirp pin in pins.jdn after checking its sha256, and calls the driver with no per-test list.
  - tools/release/pin-chirp.janet moves the :chirp pin to a published release after checking its signed sums, the chirp-release skill runs it at the step to the next -dev, and the README says how to run the tests.
---

# task/repo-tests

## Purpose
Test chirp's own Janet logic in seconds, without a container build, and run the repo checks in CI without waiting for one (review finding 4; DESIGN.md of the milestone).

## Scope
In: the test driver `tools/test.janet`; first tests beside `update.janet`, `help.janet`, `skills.janet` and `source.janet`; the CI `checks` job on a pinned released chirp; the tool that moves that pin; the README and release skill lines that mention them.
Out: the smoke checks, which stay black-box and per target (D-DPSCZ2KCZA4UB7YM); tests of `ca.janet`, `repl.janet` and `main.janet`, whose logic is the OS's or the image's; skipping builds for `.work/`-only pushes (task ci-work-only, wave B).

## Context & constraints
The tools already keep `x.test.janet` beside `x.janet`, and `test/smoke/self-update.janet` already imports `src/chirp/update` from the checkout, so a test of source needs no build. The owner chose a pinned released chirp for the CI checks (2026-11-24). `cut.janet` edits offline and before the release exists (D-MB5WIOASYBDI7AEB), so moving the pin, which needs the published release's signed sums, is a tool of its own. Design in the milestone's DESIGN.md (U-HM3MZPOZSVLCXGNP), finding 4.


## Next
Push the wave branch; the checks job must fetch the pin, pass, and not wait for build. If main's branch rules require a check named leakcheck, the owner renames it to checks. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- chirp tools/test.janet finds 13 test files by name (4 new beside src/chirp, pin-chirp and pin.sh tests, the 3 vendored dev-proc tests, the 4 tool tests) and passes with the installed 0.13.0-dev and with the released 0.13.1 under a cleared environment. chirp's own (tools/test.janet src tools): 10 files in 0.9 s. All 13 side by side: 28 to 60 s on this machine, the vendored dev-proc.test.janet alone taking 28 s or more.
- With compare-pre's numeric-below-alphanumeric rule flipped, the driver exits 1 naming update.test.janet and the failing pairs; restored, it passes.
- leakcheck's and skillcheck's test.janet are renamed leakcheck.test.janet and skillcheck.test.janet so the driver finds them; allow.jdn follows.
- pins.jdn has :chirp (0.13.1 linux-x64, sha256 from the signed SHA256SUMS; the download matches). pin-chirp.janet 0.13.1 on the real release verifies the signature and leaves pins.jdn byte-identical; 0.13.0 rewrites only that line; an unpublished version exits 1 with pins.jdn unchanged.
- parse-sums and latest-release (update.janet) and install-skill (skills.janet) are public now: they are the seams the tests use. Neither module is importable by a user's script, so nothing public to users changed.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: CI's repo checks run on a released chirp pinned in pins.jdn, not on the binary the run built (BR, 2026-11-24); pin-chirp.janet moves it at each release
- [ ] backlog: the vendored dev-proc.test.janet takes 28 s or more and sets the floor of a full test run; faster is the upstream tools repo's to do

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
