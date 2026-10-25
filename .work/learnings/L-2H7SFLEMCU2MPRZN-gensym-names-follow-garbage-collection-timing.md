---
date: 2026-10-25
read_if:
  - the a and b build hashes differ
  - changing how the image is written
refs:
  - tools/build/image.janet#gcsetinterval
---

# L-2H7SFLEMCU2MPRZN Gensym names follow garbage-collection timing

## Observation
Janet's gensym hands out again the name of a gensym the collector has freed. When collections run depends on how much the process has allocated, and the image build allocates a little more for a longer out-dir path. So CI's a and b copies, built in directories of different depth, ended up with different gensym names in the image. Adding yaml shifted a collection; earlier builds matched by luck. A diff of `strings` from both binaries showing only `_0000xx` names is the tell.

## Why it matters
Anything that changes allocation before or while the entry point compiles can bring the drift back unless the collector stays off for the whole image build. It stops being true if Janet's gensym stops reusing freed names, or if the image build ever allocates past the collection interval set there, in which case a collection happens again and the compare job catches it.
