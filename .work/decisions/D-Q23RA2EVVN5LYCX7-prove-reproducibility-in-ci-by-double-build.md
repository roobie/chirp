---
status: accepted
date: 2026-10-24
read_if:
  - changing the build or CI
  - a reproducibility check fails
refs:
---

# D-Q23RA2EVVN5LYCX7 Prove reproducibility in CI by double build

## Context
chirp promises a reproducible binary. A promise like that only holds if it is checked every time.

## Decision
CI builds every target twice, with a different path, time and runner each time, and fails if the two sha256 hashes differ.

## Why
Arguing that a build is reproducible does not catch regressions, and a double build does. The Janet core does not get in the way: its hash key defaults to zero and `JANET_BUILD` can be overridden. The remaining risk is the order of tables with pointer-hashed keys in the marshaled image, and only a real double build will show whether that is a problem.

## Consequences
Anything in the build that is not deterministic fails CI. That includes timestamps, absolute paths and the order of pointer-hashed tables.
