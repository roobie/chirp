---
created: 2026-10-24
---

# B-TNLZX72EA5GKCZZK Keep jsec error buffers thread-local under zig on windows

## Why
jsec marks its error buffers `__declspec(thread)`, which zig's clang ignores for the windows target (it warns `unknown attribute 'thread' ignored`). The buffers then become shared statics, so two janet threads (`ev/thread`) doing TLS at once can overwrite each other's error text.

## Notes
Try `-fdeclspec` or `-fms-extensions` in the windows target's `:cflags` first. If neither works, ask jsec to use `_Thread_local` or `__thread` under clang.
