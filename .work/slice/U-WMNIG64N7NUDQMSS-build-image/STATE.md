---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-26
success_criteria:
  - A GitHub workflow in this repo builds the derived build image (the pinned alpine plus packages.txt) and pushes it to GHCR as a public package.
  - pins.jdn pins the derived image by digest, and container.sh runs that image without running apk add.
  - The CI double build still produces identical hashes for all four targets using the derived image.
  - The package versions inside the image are recorded and can be read from the image itself.
---

# slice/build-image

## Purpose
Fix every package the build uses, not just the base image, so that a changed output hash always traces to a change in `pins.jdn`.

## Scope
In: a Dockerfile for the derived image, a workflow that builds and pushes it to GHCR, the pin in `pins.jdn`, and `container.sh` and `container-inner.sh` using it.
Out: multi-arch images (zig cross-compiles, so the container only needs to be amd64), and macOS and Windows host builds.

## Context & constraints
Today `container-inner.sh` runs `apk add` on `packages.txt` at build time. The derived image must be public, since the repo is public and CI pulls it unauthenticated. Rebuilding the image changes the digest and so needs a pin bump. Nothing host-specific may be committed (AGENTS.md).

### Origin
Promoted from backlog: B-F5N23HMBQOAK7EHX Pin or record the build container's apk packages

### Why
The image digest is pinned, but the packages the build installs into it at run time are not. A repository update can change perl, make or git under a fixed digest. perl generates parts of OpenSSL, so a new perl can change the output hash and leave nothing in `pins.jdn` to explain why. zig removes the compiler from this list but not the others.

### Notes
The options are a derived image built once and pinned by its own digest, or versions pinned with `apk add pkg=ver` (Alpine drops old versions, so this goes stale). Either way the versions should end up in the build record.


## Now
Pin and scripts switched to the derived image; waiting for CI's double build.

## Next
- Check the CI double build on the pushed commit
- Finalize: harvest the decision (derived image, immutable tags) and close the slice

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Workflow run 40424979766 pushed ghcr.io/roobie/chirp-build with 51 packages, package made public, unauthenticated pull works.
- Local linux-x64 build with the derived image (no apk add) gave sha256 4a712ff6f70b14b8549a89225ffd932878342246b695561fc372711e00d08a6b, identical to the earlier build that ran apk add at build time; its package list equals tools/build/apk-versions.txt.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-10-26 initialized
- 2026-10-26 phase initialize → execute
- 2026-10-26 wrote Dockerfile and build-image workflow; waiting for the first run
- 2026-10-27 pinned :build-image, switched container.sh and container-inner.sh, local hash unchanged
