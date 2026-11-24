---
date: 2026-11-24
read_if:
  - adding or changing a :notices entry
  - adding a target that leaves natives out
  - the build says a target carries a pin with no notice
refs:
  - tools/build/config.jdn#:notices
  - tools/build/config.jdn#:janet-sources
  - tools/build/build.janet#notice-applies?
---

# L-JHSEB5OVK5G34PN6 The image is the same on every target, so a pin whose Janet source is bundled is carried even by a target that links none of its natives

## Observation
jsec's notice was limited to targets that link OpenSSL, on the reasoning that only they link jsec. But the image is written once on the build machine and holds jsec's Janet modules for every target, so chirp.wasm, which links no jsec native, still carried jsec code and shipped without its license text. The build's notices guard found it the first time it ran for wasm.

## Why it matters
A notice's target limits must follow where the code ends up, and Janet source ends up everywhere. Only a component that is purely linked C, such as OpenSSL or a libc, can be limited to the targets that link it. It stops being true if targets ever get images of their own.
