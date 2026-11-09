---
date: 2026-11-09
read_if:
  - a bundled C library declares thread-local data for windows
  - a zig build warns 'unknown attribute thread ignored'
refs:
  - tools/build/config.jdn
---

# L-MMOQJTXSQIJQ4CCS zig clang needs -fms-extensions for __declspec(thread) on windows

## Observation
With the pinned zig 0.15.2 and `-target x86_64-windows-gnu`, `static __declspec(thread) char buf[16];` warns "unknown attribute 'thread' ignored" and lands in `.bss`. `-fdeclspec` changes the warning to "'thread' attribute ignored" and still yields `.bss`. Only `-fms-extensions` puts it in `.tls$`, with no warning. Check with `objdump -h` on the object.

## Why it matters
An ignored thread-local is silently shared by every thread. chirp gives jsec the flag through `:pin-cflags` in the windows target. If jsec switches to `_Thread_local` under clang, the flag can go.
