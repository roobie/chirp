---
date: 2026-11-10
read_if:
  - building janet with JANET_NO_* switches
  - a core function is nil but has a docstring
  - an image loads but a call fails with 'nil called'
refs:
  - tools/build/build.janet#stubs-source
---

# L-LCC7Y7XS6R6AQRH5 A janet built with JANET_NO_* keeps core entries for what it compiled out, with a nil value

## Observation
janet.c's embedded core image is made by the bootstrap janet, which has every feature. Compiled with JANET_NO_EV, NO_NET, NO_PROCESSES and the like, the core env still holds entries for `os/spawn`, `ev/sleep` and the rest (docstring and source map) whose `:value` is nil, because unmarshalling resolves a function name the build lacks to nil without an error. The same holds for any image: chirp's host-built image loaded in wasm with 85 core functions and every jsec binding silently nil.

## Why it matters
A missing function shows up as `nil called with N arguments` at the first call, far from the cause, and `(doc …)` still documents it. Checking whether a name is defined must look at the entry's value, not at whether the entry exists.
