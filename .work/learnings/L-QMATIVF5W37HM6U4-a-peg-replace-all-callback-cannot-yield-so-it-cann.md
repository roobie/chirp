---
date: 2026-10-27
read_if:
  - calling os/execute, sh/exec or ev code from a peg or other C callback
  - the error nil coerced from await to error
refs:
  - site/build.janet#fix-links
---

# L-QMATIVF5W37HM6U4 A peg/replace-all callback cannot yield, so it cannot run subprocesses

## Observation
`os/execute` inside a `peg/replace-all` replacement function fails with `nil coerced from await to error`. The callback runs under a C frame, and anything that yields to the event loop (subprocesses, `ev`, sh/exec-slurp) cannot suspend across it. `fix-links` resolves every link first and only substitutes inside the callback.

## Why it matters
Any Janet callback invoked from C (peg replacements, sort comparators, md4c or other native callbacks) must stay pure. This stops applying if Janet makes those C functions yield-safe.
