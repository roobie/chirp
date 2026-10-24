---
date: 2026-10-24
read_if:
  - build hashes differ between runs
  - adding a module to the bundle
refs:
  - src/chirp/chirp.jdn
---

# L-AGD7ZVHWYRGFIEDF A bundled module that stringifies an uncompiled peg leaks a heap address into the image

## Observation
spork/schema builds an error string from an uncompiled peg tuple at load time. The string holds the tuple's ASLR-dependent address, so any module that runs this at top level (spork/tasker) makes two image builds differ by a few bytes.

## Why it matters
Each new bundled module can break the double-build check (D-Q23RA2EVVN5LYCX7) this way. When hashes differ, diff the two images for `0x7F…` addresses before suspecting the toolchain. This stops applying once spork compiles the peg or stops formatting it (B-MKHM34WSTBQOE626).
