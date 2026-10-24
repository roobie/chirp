---
phase: execute
parent: U-EP6NS3X66GBL2AQL
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - Every shipped target, linux-x64 included, is compiled and linked by the pinned zig; the container's own compiler builds only the tooling that writes the image
  - test/spike/run.sh passes, with two linux-x64 builds in different directories giving identical sha256, and the binary is a static, stripped x86-64 ELF
  - test/spike/run-windows.sh still passes and reproduces
---

# slice/linux-x64-on-zig

## Purpose
Under D-I6U4X6Q5KJD2Y4SM every shipped binary comes from one toolchain. linux x64 still comes from the container's gcc, so it takes a separate code path from windows and a different source of drift. Moving it onto zig leaves one path for the matrix to grow on.

## Scope
In: splitting the build machine from the shipped targets in `config.jdn` and `build.janet`; linux-x64 cross-built with `x86_64-linux-musl`; both spike scripts.
Out: other targets; CI; building the tooling itself with zig.

## Context & constraints
- The build machine builds janet, OpenSSL and the natives that the image-building janet loads. That tooling never ships.
- The windows hash may change only if the restructure changes its inputs, and any change has to be explained.

## Now
Initialized.

## Next
- Delegate the change, review it, run both spike scripts.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
