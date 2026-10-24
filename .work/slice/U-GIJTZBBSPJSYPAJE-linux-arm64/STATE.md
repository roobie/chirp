---
phase: execute
parent: U-EP6NS3X66GBL2AQL
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - The CI run builds linux-arm64 twice and both copies hash the same
  - The linux-arm64 binary passes the smoke checks on a native ubuntu-24.04-arm runner in that run
---

# slice/linux-arm64

## Purpose
chirp ships for linux arm64 (servers, Graviton, Raspberry Pi class boards). Since every target is cross-built by zig (D-I6U4X6Q5KJD2Y4SM), this target should be data only, and this slice tests that claim.

## Scope
In: a `:linux-arm64` entry in `tools/build/config.jdn`; its entries in the CI build and smoke matrices.
Out: macos-arm64 (the next slice); any change to how the image is built.

## Context & constraints
- The image is built on the x64 build machine and carried to the target. That should hold because arm64 is also 64-bit little-endian (D-I6U4X6Q5KJD2Y4SM consequences).
- Static musl, no build-id, as for linux-x64.

## Now
The config entry and the CI matrix entries are in. The local build worked on the first try, so the target is data only, as D-I6U4X6Q5KJD2Y4SM predicted.

## Next
- Push after the ci-workflow run in flight goes green, then check the arm64 hashes and smoke in CI. This host has no arm64 emulation, so the native runner is the first place it runs.

## Evidence
- Local build: static aarch64 ELF, sha256 456e7204…a780.

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
