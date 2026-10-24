---
status: accepted
date: 2026-10-24
read_if:
  - needing system calls beyond os/
refs:
---

# D-HCB4FUBWJ2TJFZGI Skip llmII/jsys for now

## Context
llmII/jsys offers system bindings beyond Janet's `os/` module.

## Decision
Do not bundle jsys for now.

## Why
It has been dormant since 2021 and calls itself untested, and `os/` covers most of what we need. BR will contact llmII separately about its status.

## Consequences
Revisit this when a concrete need goes beyond `os/`, or when that conversation with llmII happens.
