---
status: accepted
date: 2026-10-24
read_if:
  - changing how the chirp binary is built
  - adding a bundled native module
refs:
---

# D-MNNDC6PNBUNZXT7O Build chirp as a Janet executable, not a patched core

## Context
chirp must behave like stock `janet` (REPL and script runner), with TLS and HTTP modules available without installing anything.

## Decision
Build chirp as a native Janet executable whose Janet main mimics the stock REPL/runner and preloads every bundled module, with the native modules statically linked.

## Why
Janet already supports native executables with static native modules, so the core needs no patches. That follows from D-ZBIADZDYXYPWLX5L. Patching the core's main would mean a fork.

## Consequences
chirp's main has to keep up with how the stock runner behaves, since it imitates it rather than reusing it. Each bundled native module needs a static-link recipe.
