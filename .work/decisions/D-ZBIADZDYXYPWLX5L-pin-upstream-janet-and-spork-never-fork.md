---
status: accepted
date: 2026-10-24
read_if:
  - upgrading janet or spork
  - tempted to patch upstream code
refs:
---

# D-ZBIADZDYXYPWLX5L Pin upstream janet and spork; never fork

## Context
chirp bundles janet and spork. Whatever we take from upstream we must carry for as long as chirp exists.

## Decision
Depend on pinned upstream revisions of janet and spork.

## Why
With a pin, an upgrade is a pin bump. With a fork, every upstream release becomes a merge, and that cost grows over time. Forking would only win if upstream refused a change we cannot live without, and no such change exists.

## Consequences
Anything chirp needs has to live outside the core: in chirp's own main, in bundled modules, or as a change offered upstream. Local patches to janet or spork are not allowed.
