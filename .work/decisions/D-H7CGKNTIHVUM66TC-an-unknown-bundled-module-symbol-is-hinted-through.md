---
status: accepted
date: 2026-11-20
read_if:
  - changing how compile errors are reported or hinted
  - adding a hook to root-env
refs:
  - src/chirp/main.janet#missing-symbol-hint
---

# D-H7CGKNTIHVUM66TC An unknown bundled-module symbol is hinted through the compiler's :missing-symbol hook

## Context
An unknown symbol such as `crypto/digest` should name the bundled module that provides it (#22). Scripts report compile errors through `bad-compile`, `-e` through `eval` raising, and the REPL through `run-context`. Each of those is bound inside Janet's boot image as a constant, so none can be replaced from chirp, and chirp's own mirror of Janet's runner (`run-stdin`) covers only one of those paths.

## Decision
chirp sets the `:missing-symbol` handler in `root-env`, which the compiler asks for any symbol it cannot resolve and which every environment inherits. The handler raises the hint for a `prefix/name` whose prefix is a bundled module's short name and whose module exports that name publicly, and returns nil otherwise, leaving Janet's error.

## Why
- **Per-path `:on-compile-error` wrappers:** rejected. They would need chirp to reimplement the script runner and `-e`, and would miss any other path that compiles.
- **Patching boot.janet or the compiler in the build:** rejected. It forks Janet for something its own hook already does.
- **Stub bindings for every bundled function:** rejected. They would make the symbol resolve, which turns a compile error into a runtime one, and they pollute completion and `all-bindings`.
- The hook is a supported compiler feature and sits only on the path where the symbol is already unknown, so defined and imported symbols never reach it.

## Consequences
- Janet prefixes the handler's error with `(lookup) `, so the message reads `error: (lookup) unknown symbol crypto/digest; chirp bundles crypto: ...`.
- Hints are given only for names the bundled module exports, so a typo such as `math/flor` or a user's own module sharing a bundled short name keeps Janet's plain error.
- Code in an `ev/thread` gets Janet's plain error, since the handler lives in the main thread's `root-env`.
- Anything else that sets `:missing-symbol` in a user environment replaces chirp's hint there.
