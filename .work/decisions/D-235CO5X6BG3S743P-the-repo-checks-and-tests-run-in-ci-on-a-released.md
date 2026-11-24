---
status: accepted
date: 2026-11-24
read_if:
  - changing the checks job or what runs the repo's tests in CI
  - cutting a release or moving main to the next -dev
  - a test needs a chirp feature newer than the last release
refs:
  - pins.jdn
  - tools/release/pin-chirp.janet#repin
  - tools/test.janet
  - .github/workflows/ci.yml
---

# D-235CO5X6BG3S743P The repo checks and tests run in CI on a released chirp pinned in pins.jdn, not on the binary the run built

## Context
The repo checks (leakcheck, skillcheck, the tool tests) ran in a CI job that needed the build job, so each waited about 20 minutes for ten cold builds to say something a second of Janet can say. The review of 2026-11-24 also found no test of chirp's own Janet below a container build.

## Decision
The checks and every `*.test.janet` run on a released linux-x64 chirp, pinned by URL and sha256 like every other input, and the job no longer waits for the build (BR, 2026-11-24). The pin moves to each release once it is published.

## Why
The alternative was to keep the built binary: it dogfoods, but it puts the build between a typo and its report, and it would have kept the checks from running at all for a push that builds nothing. A separately installed janet was ruled out long ago, since the tools need chirp's bundled modules. The binaries a run builds are still exercised, by the smoke job on every target. Moving the pin is a tool of its own and not part of the release cut, because it needs the published release's signed sums and the cut runs before the release exists and offline.

## Consequences
A test may use only what the pinned release has; one that needs something newer waits for a release, or says so and skips. The pin is one more step after a release, in the release skill. A release that could not run the repo's own tests would be found when the pin moves, after it shipped.
