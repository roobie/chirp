---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-27
success_criteria:
  - '`(import pcre2)` works in the built binary on all four targets with nothing on disk, and the CI smoke check exercises it.'
  - The module offers match, find-all, replace with group references, split and named groups, with PCRE2 match and depth limits that have safe defaults.
  - A pattern with catastrophic backtracking fails with an error instead of hanging.
  - The CI double build is still identical for all four targets, and the release notices carry PCRE2's license text.
  - README and the changelog say what the module is, and `chirp help` finds its docs.
---

# slice/pcre2

## Purpose
Scripts paste patterns from grep, sed and Python, and spork/regex covers only a subset. A standard Perl-style regex removes a common reason to reach for another tool.

## Scope
In: pin PCRE2, a chirp-owned binding in `src/pcre2`, a native entry in `tools/build/natives.jdn`, the API above, smoke checks, docs and notices.
Out: JIT unless a benchmark justifies it, and anything beyond the API above (callouts, custom character tables).

## Context & constraints
Follows the libyaml pattern: a pinned library plus a repo-owned binding (D-FD4ZWTDKYJBQBFRO, D-VOBKZC6H4OPIMPQE). PCRE2 is BSD-3-Clause, compatible with MIT redistribution (D-UQZLUV7LGGRXHXPJ). A new module can break the double-build check (L-AGD7ZVHWYRGFIEDF). The four targets are built by zig from a pinned container (D-TM4MP66QJOMXDMI5).

### Origin
Promoted from backlog: B-Z2YSVOZUFFWATVPJ Bundle PCRE2 regex

### Why
Scripts copy patterns from grep, sed, Python and documentation, and those use Perl-style syntax. spork/regex covers a subset, and PEGs are powerful but are not what people paste. Standard regex removes a common reason to fall back to another tool.

### Notes
- PCRE2 is BSD-3-Clause; it would follow the libyaml pattern: pinned library plus a chirp-owned binding (D-FD4ZWTDKYJBQBFRO).
- JIT is optional and platform-dependent; the interpreter alone keeps the four-target build simple. Decide with a benchmark.
- Matches on untrusted input can backtrack catastrophically; expose PCRE2's match and depth limits with safe defaults.
- API to settle: match, find-all, replace with group references, split, named groups.


## Now
Implemented and verified locally on linux-x64; waiting for CI on all four targets.

## Next
- Check CI: the double build, the smoke check on each target, the notices
- Finalize: record the design decision and close the slice

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Local linux-x64: test/smoke/run.janet passes including the new pcre2 check; `(^(a+)+$)` on 40 a's plus `!` fails with the match-limit error in about 0.1s with default limits.
- Two fresh linux-x64 builds in different directories give the same sha256 (a279e7f689770d6eb1b58e0b25f8b899e97a5ce8318d833c356aaf76aa501d55).
- `chirp help query pcre2` lists the functions; README examples were run and their output checked.

## Harvest
- [ ] decision: pcre2 module design: name, API shape, counted limits only (no time limit, no callouts), interpreter only (no JIT), UTF-8 by default
- [ ] learning: JANET_FN functions are global symbols, so a new native needs its own prefix (cfun_version clashed with spork/zip and cfun_compile with Janet at link time)

## Log
- 2026-10-27 initialized
- 2026-10-27 phase initialize → execute
- 2026-10-27 binding, build wiring, smoke check and docs written; local build deterministic
