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
Bumping the version.

## Next
- Dispatch a dry run on the bump commit; hand the tag command to BR.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
