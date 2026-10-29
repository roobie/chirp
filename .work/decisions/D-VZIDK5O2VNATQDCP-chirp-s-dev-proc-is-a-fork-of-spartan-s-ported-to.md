---
status: accepted
date: 2026-10-25
read_if:
  - changing the dev-proc CLI
  - syncing dev-proc with other repos
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet
---

# D-VZIDK5O2VNATQDCP chirp's dev-proc is a fork of spartan's, ported to chirp

## Context
Five repos carried the same Node copy of dev-proc, with spartan's as the upstream. chirp's own process tool running on Node contradicted what chirp is for: one binary in place of extra runtimes.

## Decision
chirp keeps its own copy of dev-proc, written for chirp. The other repos keep Node.

## Why
Porting only chirp's copy puts chirp under daily use without asking the other repos to install it. Porting every copy at once would have forced chirp on repos that have not chosen it. Staying on Node would have kept the contradiction. The commands behave as Node's did, apart from find and front matter errors, so the copy can be offered back upstream.

## Consequences
Changes made to spartan's copy no longer reach chirp on their own, and the reverse holds too. Each one has to be ported by hand. Working in this repo needs chirp on the PATH. Without it, the hooks skip the dev-proc checks.
