---
created: 2026-11-10
needs: owner
---

# B-GUXSNK7MDKPJWBUW Upstream Janet's wasi build fixes and os/cryptorand on wasi

## Why
The wasm32-wasi target carries shims in src/wasm/ for gaps Janet 1.43 hits on wasi-libc (D-HA7ATG3IF6P73TOI). Upstream they help every Janet wasm user and the shims go away. os/cryptorand fails on wasi because Janet reads /dev/urandom there, while wasi-libc has arc4random_buf.

## Notes
- `tzset` and `CLOCK_PROCESS_CPUTIME_ID` (os.c, util.c), `dup` (io.c, new since 1.37), `<sys/wait.h>` and `<spawn.h>` included unconditionally on posix though only processes need them, `tmpfile` (file/temp).
- janet_cryptorand: take the arc4random_buf branch for `__wasi__` too.
- Janet's CONTRIBUTING asks for emscripten builds to keep working; a wasi CI job would be the natural ask.
