---
phase: execute
parent: U-ROTWPYUJJW5Q45E2
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - src/chirp/chirp.jdn says version 0.1.0, and the built binary's identity line says chirp 0.1.0
  - A release dry run on that commit is green and produces assets named chirp-0.1.0-<target>
  - BR has the exact command to push the v0.1.0 tag, and nothing else is left
---

# slice/cut-0-1-0

## Purpose
Make cutting 0.1.0 a single tag push, so the public step is BR's and nothing about it is improvised.

## Scope
In: the version bump and a dry run on it.
Out: pushing the tag (BR).

## Context & constraints
- The version is read into the image, so the bump changes every binary hash. The dry run shows the new ones.

## Now
Handed to BR: pushing the v0.1.0 tag is the only step left.

## Next
- After BR's tag push: check that the release run is green, the release has 9 assets, and `sha256sum -c` passes on a download. Then finalize this slice and the milestone.

## Evidence
- Dry run 40101554570 (dispatch on c3a8c03) is green in all 16 jobs. The downloaded `release-0.1.0` artifact passes `sha256sum -c SHA256SUMS` for all 8 files, and `chirp-0.1.0-linux-x64 --version` prints `chirp 0.1.0 (unofficial build, not a Janet release)`. No release or tag exists.
- The 0.1.0 hashes are linux-x64 a46cf92d…88ad, linux-arm64 e6720a58…88d6, macos-arm64 d3c13030…23a9 and windows-x64 9bc9ab15…acf.

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
