---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A GitHub Actions workflow builds linux-x64, linux-arm64, macos-arm64 and windows-x64 with the pinned zig, each target twice in separate jobs and different directories, and fails when the two sha256 differ
  - Each target's binary passes its smoke checks (identity line, zip round-trip, HTTPS GET with verification on, a self-signed host rejected) on a native GitHub runner for that platform
  - The workflow's latest run on main is green
---

# milestone/build-matrix

## Purpose
The project promises one reproducible chirp for four targets (D-Q23RA2EVVN5LYCX7). Until CI builds and runs every target, that promise has been checked on one machine for two targets. This milestone makes GitHub check it on every push.

## Scope
In: moving linux x64 onto zig; the linux-arm64 and macos-arm64 targets; a GitHub Actions workflow with a double build per target, a hash comparison and native smoke runs; leakcheck in CI (B-JSN4UWUJCBBNOWEX).
Out: releases and provenance attestation; the embedded CA bundle (D-B2RTYH6CNDO6SRF5), so smoke runs point at a CA bundle the runner provides where needed; SQLite and TOML (U-OPXF3E6S7PBCFAHC); a native windows TLS backend (B-7VZIOC4LFIUJMWA2).

## Context & constraints
- Decisions: D-I6U4X6Q5KJD2Y4SM (zig everywhere, cross-built from linux), D-Q23RA2EVVN5LYCX7 (double build), D-URDDGCK3H3MPSCTM (GitHub Actions), D-3GLX6D2RADC6IDG7 (pinned container hosts the build).
- Every build runs in the pinned container on a linux x64 runner. Native runners only run binaries: ubuntu x64, ubuntu arm64, macOS arm64 and windows x64.
- macOS can't be run locally; its evidence comes only from CI.
- GitHub access goes through the repo-scoped token, per command.

## Slices (in order; each one ships with CI evidence)
1. linux-x64-on-zig: linux x64 is built by zig like windows, and run.sh stays green and reproducible.
2. ci-workflow: the workflow for linux-x64 and windows-x64, plus leakcheck.
3. linux-arm64: the target plus its native smoke job.
4. macos-arm64: the target plus its native smoke job.

## Now
Initializing; slice 1 next.

## Next
- Open slice linux-x64-on-zig.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
