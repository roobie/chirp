---
status: accepted
date: 2026-10-24
read_if:
  - writing README, release notes or version strings
refs:
---

# D-J2C4TCJIQLJGENAG Mark chirp as unofficial

## Context
chirp ships Janet under a different name, together with third-party modules.

## Decision
chirp must say clearly that it is unofficial and must never look like an official Janet release.

## Why
If users mistook chirp for an official release, they would blame Janet's maintainers for chirp's choices and bugs.

## Consequences
The README, release notes, version output and REPL banner all say chirp is unofficial.
