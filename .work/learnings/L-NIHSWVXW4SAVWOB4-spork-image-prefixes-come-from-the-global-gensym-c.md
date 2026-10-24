---
date: 2026-10-24
read_if:
  - an exe differs between two builds of the same inputs
  - using spork declare-executable with native modules
refs:
  - tools/build/build.janet#patch
---

# L-NIHSWVXW4SAVWOB4 spork image prefixes come from the global gensym counter, so images vary between identical builds

## Observation
Two clean builds of the same inputs differed in about 660 bytes, roughly one pair in three or four, with no path or timing cause. The differing bytes were the native function names inside the image and the call order of the native entry functions in the generated C main.

## Why it matters
The spork pin names natives with a process-global counter, so anything that calls it earlier in the build process shifts every name. Reproducibility therefore needs the patch in `refs`; a linux build passing once proves nothing. It stops being true once a pinned spork numbers prefixes locally.
