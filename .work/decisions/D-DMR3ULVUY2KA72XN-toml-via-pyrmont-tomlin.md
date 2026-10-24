---
status: accepted
date: 2026-10-24
read_if:
  - reading or writing TOML in chirp
  - TOML parse errors or type surprises
refs:
---

# D-DMR3ULVUY2KA72XN TOML via pyrmont/tomlin

## Context
BR wants TOML in chirp unless it is very hard to add. Neither janet nor spork can parse TOML.

## Decision
Bundle pyrmont/tomlin, pinned like the other upstreams and compiled into the image as a pure-Janet module.

## Why
It is pure Janet (a PEG grammar plus a converter, about 450 lines), MIT-licensed, aims at TOML v1.0.0 and is tested against the toml-specs conformance suite. Its vendored dependencies are only used by its tests. Adding it costs a pin and an entry in the module list, with nothing native to build. Writing our own parser would mean owning a spec implementation. A C library (e.g. tomlc99) would mean writing a binding as well as statically linking more C, with no gain.

## Consequences
TOML can only be read: tomlin has no encoder. If writing TOML is ever needed, add an encoder upstream or as a small chirp module. Integers come back as `int/s64` and date-times as tables, not as plain numbers or strings. The upstream has been quiet since 2024, which is acceptable for a stable spec. If it stops passing conformance on a janet bump, fix that upstream.
