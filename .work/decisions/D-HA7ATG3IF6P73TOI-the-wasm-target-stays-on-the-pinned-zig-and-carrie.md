---
status: proposed
date: 2026-11-10
read_if:
  - changing the wasm toolchain
  - Janet errors or longjmp misbehave in wasm
refs:
  - src/wasm/setjmp.c
  - src/wasm/compat.h
  - tools/build/config.jdn
---

# D-HA7ATG3IF6P73TOI The wasm target stays on the pinned zig and carries its own setjmp runtime

## Context
Janet's error handling is setjmp/longjmp, which on wasm needs the exception-handling proposal (`-mllvm -wasm-enable-sjlj -mexception-handling`) plus three runtime functions that wasi-libc ships as libsetjmp. zig 0.15.2 bundles wasi-libc's headers but not that library. danja/janey solves it with wasi-sdk 25 and `-lsetjmp`; Emscripten would be a third option.

## Decision
Proposed: keep the wasm32-wasi target on the pinned zig (D-I6U4X6Q5KJD2Y4SM) and compile chirp's own copy of the three functions, with the few libc gaps Janet hits filled by a force-included header and stub headers in this repo.

## Why
A second toolchain (wasi-sdk or Emscripten) would mean a second pin, a second download and a second source of drift, against the one-toolchain reason of D-I6U4X6Q5KJD2Y4SM. The runtime is about twenty lines whose layout is fixed by LLVM's lowering. The Janet gaps are small and belong upstream; carrying them as headers rather than a patch keeps Janet pinned unmodified (D-ZBIADZDYXYPWLX5L).

## Consequences
- A zig bump can change the exception-handling lowering; the wasm smoke run must cover an error path.
- The header shims shrink as fixes land upstream in Janet.
- The output needs a runtime with wasm exception handling: current Chrome, Firefox, Safari and Node have it.
