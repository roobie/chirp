---
status: accepted
date: 2026-10-27
read_if:
  - changing the pcre2 API or its default limits
  - asking for a regex time limit or the JIT
  - considering another regex library
refs:
  - src/pcre2/pcre2.c
  - tools/build/natives.jdn
  - src/pcre2/include/config.h
---

# D-LGEWD4XRBUFOEIDS pcre2 is a chirp-owned binding with counted limits and no JIT

## Context
Scripts paste patterns from grep, sed and Python, and spork/regex covers only a subset. chirp needed a Perl-style regex that builds the same on all four targets and keeps the double-build check passing.

## Decision
chirp bundles PCRE2 behind a binding it owns, as a module named `pcre2`. The API is compile, match, find-all, replace, replace-all, split and version. A pattern is a string or a compiled regex. Matching is bounded by counted limits with defaults, never by time, and the JIT is not built. Patterns and subjects are UTF-8 unless `:utf false` is passed.

## Why
A name that says `pcre2` cannot be mistaken for spork/regex, and a short name such as `re` would hide the dialect. The match, depth and heap limits make a runaway pattern fail the same way on every machine, where a time limit would depend on how fast the machine is. PCRE2 has no wall-clock limit anyway; a callout could check the clock, but it slows every match. The library's own heap limit is about 20 GB, so the binding sets its own defaults. The JIT is platform-dependent and would complicate four targets for a speed gain nobody has asked for; a benchmark can reopen it. Compile flags passed alongside an already compiled regex are an error instead of being ignored, so a flag cannot be silently dropped.

## Consequences
- A limit that is too low for a large subject fails loudly. The error names the option to raise.
- The binding follows the libyaml pattern (D-VOBKZC6H4OPIMPQE, D-FD4ZWTDKYJBQBFRO). PCRE2's generated files are replaced by shims in the repo through `:repo-includes`, so the pin stays a clean checkout.
- Callouts, custom character tables and the JIT are out of scope until asked for.
