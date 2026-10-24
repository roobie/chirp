---
status: accepted
date: 2026-10-24
read_if:
  - setting up CI or releases
  - mirroring the repo
refs:
---

# D-URDDGCK3H3MPSCTM Host on public GitHub, not the private gitea

## Context
chirp has to be built and released for linux x64/arm64 (static musl), macOS arm64 and windows x64, and users should be able to verify the releases.

## Decision
Host chirp publicly on GitHub. The private gitea may pull-mirror it as a backup.

## Why
GitHub provides free native runners for the whole platform list, plus free build-provenance attestation. On gitea we would have to provide and maintain runners for each platform ourselves.

## Consequences
CI is written for GitHub Actions.
