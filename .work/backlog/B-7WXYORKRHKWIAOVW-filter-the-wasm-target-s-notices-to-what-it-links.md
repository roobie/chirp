---
created: 2026-11-10
---

# B-7WXYORKRHKWIAOVW Filter the wasm target's NOTICES to what it links

## Why
bin/NOTICES.txt for wasm32-wasi lists OpenSSL and Zig's compiler_rt notice as on the native targets, although the wasm build links no OpenSSL. A notice for code not shipped is wrong in the other direction from a missing one.

## Notes
notices.jdn already takes `:targets` per notice; add wasm32-wasi exclusions or inclusions, and check whether zig's wasm libc (wasi-libc) needs its own notice.
