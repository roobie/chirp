---
created: 2026-10-24
---

# B-MKHM34WSTBQOE626 Make spork/tasker image-deterministic upstream and re-bundle it

## Why
spork/tasker is left out of the bundle because loading it bakes a heap address into the image (L-AGD7ZVHWYRGFIEDF), so scripts using it need it on disk.

## Notes
Fix upstream in spork/schema (compile the peg, or do not format it), then bump the spork pin and add tasker back to `src/chirp/chirp.jdn`.
