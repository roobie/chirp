---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-09
success_criteria:
  - the windows-x64 build compiles jsec with no `unknown attribute 'thread' ignored` warning, and jsec objects carry a .tls section
  - CI passes on all targets, windows smoke included; other natives and janet are compiled with unchanged flags
---

# task/jsec-tls-windows

## Purpose
zig's clang ignores jsec's `__declspec(thread)` on windows, so its error buffers are shared between janet threads.

## Scope
In: a per-pin cflags entry for the windows target giving jsec `-fms-extensions`.
Out: an upstream jsec change (only if the flag did not work).

## Context & constraints
Probed with the pinned zig 0.15.2: no flag -> warning, .bss; -fdeclspec -> 'thread attribute ignored', .bss; -fms-extensions -> no warning, .tls$ section. Janet's own JANET_THREAD_LOCAL is __thread under clang, unaffected.

### Origin
Promoted from backlog: B-TNLZX72EA5GKCZZK Keep jsec error buffers thread-local under zig on windows

### Why
jsec marks its error buffers `__declspec(thread)`, which zig's clang ignores for the windows target (it warns `unknown attribute 'thread' ignored`). The buffers then become shared statics, so two janet threads (`ev/thread`) doing TLS at once can overwrite each other's error text.

### Notes
Try `-fdeclspec` or `-fms-extensions` in the windows target's `:cflags` first. If neither works, ask jsec to use `_Thread_local` or `__thread` under clang.


## Now
Pushed; waiting for CI.

## Next
- windows build, CI, finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Local windows-x64 build: no 'thread' attribute warning in the log; jsec objects carry .tls$ (error.c.o: .tls$ 0x200 = error_buf[512], .bss 0).

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-09 initialized
- 2026-11-09 phase initialize → execute
