---
status: accepted
date: 2026-10-24
read_if:
  - TLS certificate verification fails
  - updating the CA bundle
refs:
---

# D-B2RTYH6CNDO6SRF5 CA roots: probe system paths, fall back to embedded bundle

## Context
A static OpenSSL looks for certificates under its build prefix, and that path will not exist on the machines chirp runs on.

## Decision
At runtime, look for the system CA stores in the usual locations first. If none is found, use a pinned CA bundle embedded in the binary.

## Why
Checking the system first means CA updates and revocations from the OS still apply. Using only the embedded bundle would freeze trust at build time. Using only the system store would break on minimal hosts.

## Consequences
The embedded bundle is a pin that has to be bumped from time to time. Which store was actually used should be easy to find out when debugging.
