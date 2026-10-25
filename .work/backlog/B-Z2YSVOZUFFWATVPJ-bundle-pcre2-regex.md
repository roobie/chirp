---
created: 2026-10-25
---

# B-Z2YSVOZUFFWATVPJ Bundle PCRE2 regex

## Why
Scripts copy patterns from grep, sed, Python and documentation, and those use Perl-style syntax. spork/regex covers a subset, and PEGs are powerful but are not what people paste. Standard regex removes a common reason to fall back to another tool.

## Notes
- PCRE2 is BSD-3-Clause; it would follow the libyaml pattern: pinned library plus a chirp-owned binding (D-FD4ZWTDKYJBQBFRO).
- JIT is optional and platform-dependent; the interpreter alone keeps the four-target build simple. Decide with a benchmark.
- Matches on untrusted input can backtrack catastrophically; expose PCRE2's match and depth limits with safe defaults.
- API to settle: match, find-all, replace with group references, split, named groups.
