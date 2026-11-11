---
created: 2026-11-10
needs: owner
---

# B-RS4LEZTDHMQIMIFM Offer janet-lang/sqlite3 a guard for builds without extension loading

## Why
The SQLite amalgamation omits `sqlite3_load_extension` on wasi (SQLITE_OMIT_LOAD_EXTENSION), but janet-lang/sqlite3's main.c calls it unconditionally, so the wasm target links a stub from src/wasm/libc.c.

## Notes
An `#ifndef SQLITE_OMIT_LOAD_EXTENSION` around the binding's load-extension function, raising otherwise, would remove the stub.
