---
status: accepted
date: 2026-10-24
read_if:
  - choosing or changing the C toolchain
  - adding a build target
refs:
  - tools/build/config.jdn
  - tools/build/build.janet#cross-link
  - test/spike/run-windows.sh
---

# D-I6U4X6Q5KJD2Y4SM Cross-build every target with a pinned zig

## Context
chirp ships four targets (linux x64/arm64 musl, macOS arm64, windows x64), and each build must be reproducible (D-Q23RA2EVVN5LYCX7). The linux spike used a pinned Alpine container (D-3GLX6D2RADC6IDG7), which covers linux only and leaves its apk packages unpinned.

## Decision
Use `zig cc` from one pinned zig release, verified by sha256, as the C compiler and linker for every target, cross-building from linux. Slice U-XQ7CEDXSOK3XIAZV showed it on the hardest target: a windows build that runs under Wine with TLS verification on and is byte-identical across build directories.

## Why
One toolchain means one build path and one source of drift, where native toolchains would mean four (container gcc, Xcode clang, MSVC or mingw). zig bundles libc headers for all targets and ad-hoc signs arm64 macOS binaries. The spike already takes the compiler from data, so the switch is small. The alternative, a container per platform plus native runners, costs more to keep reproducible.

## Consequences
The image must be built on the build machine, so each native module is built twice: once for the build machine to load while the image is built, and once for the target to link. The image must also carry over to the target, which should hold because every target is 64-bit little-endian. zig is pre-1.0, so a zig bump is a deliberate change that is checked by the double-build check. Building no longer needs native runners, but running each target's binary still does. The pinned Alpine container (D-3GLX6D2RADC6IDG7) stays as the build host, so the build's own janet and tools stay fixed; only its role as the source of the compiler ends, once linux moves onto zig.
