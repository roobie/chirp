---
created: 2026-11-04
---

# B-S3NXI7Y7RE7GGQPI (import json) error should point at spork/json (#8)

## Why
GitHub #8 (usage-feedback): `(import json)` fails with a bare "could not find module json". The bundled module is `spork/json`, and the top hit for `chirp --help query json` is changelog 0.3.0, whose wording ("`json/decode` and `json/encode`") suggests that a bare `json` module exists.

## Notes
- The issue suggests three remedies, any one of which would do: a "did you mean `(import spork/json :as json)`?" hint when a short name matches a bundled module; a `json` alias module; or a help topic on importing bundled modules that ranks above changelog entries.
- A hint keeps the module namespace honest (no alias modules to own). One way to do it is a last entry in `module/paths` that matches bundled short names and errors with the hint, so the real search order is left alone.
- A help topic that maps tasks to bundled modules also answers #4 (spork/misc print-table) and #6 (spork/schema), B-LXVEZMLKF5VJOQZQ.
- Short names to cover: the bundled spork modules plus chirp's own (yaml, md4c, pcre2, lexbor, omap, gzip, tar, sqlite3, tomlin).
