---
status: accepted
date: 2026-10-24
read_if:
  - working with SQLite in chirp
  - bumping the SQLite version
refs:
---

# D-Z7JOCFPGMOANQFY7 SQLite via janet-lang/sqlite3, statically linked

## Context
BR added SQLite to the project's scope. It has to work from the single static binary with nothing installed, which rules out loading a system libsqlite at runtime.

## Decision
Bundle janet-lang/sqlite3, pinned like every other upstream, with the SQLite amalgamation it ships compiled into chirp as a static native module.

## Why
It is the binding maintained by the Janet project, and it includes the amalgamation itself. One pin therefore fixes both the binding and the SQLite version, with no separate source download. The alternatives were writing our own binding, which means code to own forever, and linking a system libsqlite, which breaks the static, nothing-installed promise.

## Consequences
The SQLite version moves only when the janet-lang/sqlite3 pin is bumped. If a newer SQLite is needed before upstream updates its vendored copy, that has to be raised upstream rather than patched locally (D-ZBIADZDYXYPWLX5L).
