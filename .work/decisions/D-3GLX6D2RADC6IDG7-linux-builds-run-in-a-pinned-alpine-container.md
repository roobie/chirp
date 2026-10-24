---
status: accepted
date: 2026-10-24
read_if:
  - building chirp for linux
  - changing the build toolchain
  - a linux build differs between machines
refs:
---

# D-3GLX6D2RADC6IDG7 Linux builds run in a pinned Alpine container

## Context
The linux binaries must be static musl builds and reproducible. Build machines (developer hosts, GitHub runners) have different glibc-based toolchains, and most have no musl installed.

## Decision
Linux builds run inside an Alpine image pinned by digest. The host only needs docker.

## Why
Alpine's native libc is musl, so static linking needs no cross toolchain. A pinned digest fixes the compiler, linker and libc. A byte-identical result then depends on our inputs, not on what the host has installed. The alternatives were a host musl-gcc wrapper, which differs per distro and is often missing, and a cross toolchain we would have to build and pin ourselves, which means much more to maintain.

## Consequences
Bumping the toolchain means bumping the image digest, which can change output hashes. The image digest belongs with the other pins (D-ZOBE3ZBK764B22JY). macOS and Windows builds cannot use this and need their own reproducibility story.
