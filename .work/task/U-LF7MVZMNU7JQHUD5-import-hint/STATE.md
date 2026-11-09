---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-09
success_criteria:
  - '`(import json)` with no json module on disk fails naming `(import spork/json :as json)` and `chirp --help read tasks`; the same for every bundled module''s last path segment and a few common names (toml, sqlite, https, markdown, pcre)'
  - 'a module of that name on disk or in a project still wins: the hint is the last entry in module/paths'
  - a smoke check covers the hint, the on-disk precedence and an unknown name keeping Janet's own error
---

# task/import-hint

## Purpose
Importing a bundled module by its short name fails with Janet's bare search list (#8); the error should name the bundled import.

## Scope
In: a last-resort module/paths entry that errors with a hint; the short-name table built from `:modules` plus a small alias list in chirp.jdn; a smoke check.
Out: alias modules that make `(import json)` work; typo suggestions for misspelled full names.

## Context & constraints
Bundled modules are resolved from module/cache and a :chirp-tls loader (src/chirp/main.janet defer-tls-modules). Janet's require-1 errors with module/find's message when no path matches.

### Origin
Promoted from backlog: B-S3NXI7Y7RE7GGQPI (import json) error should point at spork/json (#8)

### Why
GitHub #8 (usage-feedback): `(import json)` fails with a bare "could not find module json". The bundled module is `spork/json`, and the top hit for `chirp --help query json` is changelog 0.3.0, whose wording ("`json/decode` and `json/encode`") suggests that a bare `json` module exists.

### Notes
- The issue suggests three remedies, any one of which would do: a "did you mean `(import spork/json :as json)`?" hint when a short name matches a bundled module; a `json` alias module; or a help topic on importing bundled modules that ranks above changelog entries.
- A hint keeps the module namespace honest (no alias modules to own). One way to do it is a last entry in `module/paths` that matches bundled short names and errors with the hint, so the real search order is left alone.
- The help-topic remedy is B-YHAOKYFCK6MVRMXE (bundled functionality by end-goal), which covers #4 and #6 too. This item is the hint at the failing import.
- Short names to cover: the bundled spork modules plus chirp's own (yaml, md4c, pcre2, lexbor, omap, gzip, tar, sqlite3, tomlin).


## Now
Pushed; waiting for CI on all targets.

## Next
- smoke check, CHANGELOG, then finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- linux-x64 build: (import json) -> 'could not find module json; chirp bundles it: (import spork/json :as json)' plus the tasks pointer; (import nosuch) keeps Janet's path list; JANET_PATH with json.janet loads it (42). Smoke run passes, import-hint included.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] backlog: chirp.md's 'Listing bundled modules' command misses the 9 TLS modules (jsec/*, spork-https), which are loaded on first require and so not in module/cache at start

## Log
- 2026-11-09 initialized
- 2026-11-09 phase initialize → execute
