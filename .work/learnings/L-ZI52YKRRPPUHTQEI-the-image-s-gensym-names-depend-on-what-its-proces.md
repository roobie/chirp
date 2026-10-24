---
date: 2026-10-24
read_if:
  - an exe differs between two builds of the same inputs
  - editing the build scripts changes output hashes
refs:
  - tools/build/image.janet
---

# L-ZI52YKRRPPUHTQEI The image's gensym names depend on what its process compiled first

## Observation
Adding a single `or` to the build script changed the windows hash, while both builds still agreed with each other. The only differing bytes were gensym names in the image. Macros compiled earlier in the same process had moved janet's process-wide gensym counter, so chirp's main got different names.

## Why it matters
Any code that runs in the image-writing process before the entry is compiled is an input to every hash. Keep that process a small dedicated script that rarely changes, and expect a hash change when it does. This is separate from spork's prefix counter (L-NIHSWVXW4SAVWOB4). It would stop being true if janet's gensym counter could be reset, or if gensym names stopped reaching the marshaled image.
