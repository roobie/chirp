---
created: 2026-10-25
---

# B-6LSXCQXV5LOOALKI omap marshal, deep= by content, and a per-thread print guard

## Why
An omap cannot be marshalled, so it cannot be sent to another ev thread or saved in an image. `deep=` compares two omaps by identity, so tests have to convert them first. The guard against printing a map that holds itself is one process-wide counter, which threads printing at the same time could confuse.

## Notes
Janet abstract types can supply marshal and unmarshal callbacks; `deep=` has no hook for abstracts, so content equality may need an `omap/equal?`.
