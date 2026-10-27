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
`tools/build/Dockerfile` and `.github/workflows/build-image.yml` are written but not committed or run. The workflow is manual (`workflow_dispatch`) and prints the digest to pin.

## Next
- Commit and push the workflow, run it once, and make the GHCR package public (first push creates it private)
- Add `:build-image` to `pins.jdn` with the printed digest
- Switch `container.sh` to `:build-image` and drop `apk add` from `container-inner.sh`
- Run CI and check the double build hashes

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
- 2026-10-26 initialized
- 2026-10-26 phase initialize → execute
- 2026-10-26 wrote Dockerfile and build-image workflow; waiting for the first run
