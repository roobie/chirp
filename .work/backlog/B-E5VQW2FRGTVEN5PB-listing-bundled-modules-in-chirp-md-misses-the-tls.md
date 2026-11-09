---
created: 2026-11-09
---

# B-E5VQW2FRGTVEN5PB Listing bundled modules in chirp.md misses the TLS modules

## Why
`chirp --help read chirp` lists bundled modules with `(keys module/cache)`, but jsec/* and spork-https are loaded on first require (so the OS trust store is exported only when needed) and are not in the cache at start: the command prints 45 of 54.

## Notes
- Fix the command (e.g. include the :chirp-tls path entry's names) or expose the list some other way; `help/tasks.md` already names all 54 by goal.
