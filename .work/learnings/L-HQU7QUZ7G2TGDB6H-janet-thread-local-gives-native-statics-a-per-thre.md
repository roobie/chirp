---
date: 2026-11-11
read_if:
  - keeping static state in a native module
  - a counter or cache in C shared across ev threads
refs:
  - src/omap/omap.h#omap_depth
---

# L-HQU7QUZ7G2TGDB6H JANET_THREAD_LOCAL gives native statics a per-thread copy on every chirp target

## Observation
`JANET_THREAD_LOCAL` from janet.h makes a C static per thread on every target chirp builds. It is `__thread` under gcc and clang, including zig's windows target, where the variable lands in the `.tls$` section. It is empty in the single-threaded wasm build. No `-fms-extensions` is needed.

## Why it matters
A native module's static state (recursion counters, caches) is shared across ev threads unless declared this way, so one thread's work can trip another's guard.
