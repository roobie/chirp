---
status: proposed
date: 2026-10-24
read_if:
  - touching janet hash key or JANET_BUILD
  - hardening the HTTP server against hash flooding
refs:
---

# D-ZBOSG3RYRJVCOMXZ Hash key zero at build, randomized at runtime

## Context
A reproducible build needs a fixed hash key (D-Q23RA2EVVN5LYCX7). But a public HTTP server whose hash key is known can be attacked by hash flooding.

## Decision
Proposed: keep the hash key at zero while building the image, and randomize it when the binary starts.

## Why
This gets both a reproducible artifact and resistance to flooding at runtime. A fixed key everywhere would make the server easy to flood. A random key at build time would break reproducibility.

## Consequences
Still open: it has to be confirmed that changing the key at runtime is safe for tables that were loaded from the marshaled image.
