---
created: 2026-10-24
---

# B-SL7UR7XROZ4VL3PE jsec's thread-local error buffer is a plain static under zig

## Why
zig/clang ignores `__declspec(thread)` in jsec's `src/jutils/error.c` (it warns "unknown attribute 'thread' ignored"), so on windows the error buffer is shared by all threads. That's harmless while chirp runs Janet on one thread, but wrong once threads (`ev/thread`) report TLS errors at the same time.

## Notes
`_Thread_local` or `__thread` would work with zig. Small enough to upstream with B-5AUA2Q7IH5DP2ZME.
