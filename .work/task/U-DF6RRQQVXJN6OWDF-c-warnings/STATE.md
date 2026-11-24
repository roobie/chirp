---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - Five targets build twice with matching hashes under -Wall -Wextra -Werror on repo sources.
  - Every exemption is written down with its reason.
  - Any behaviour fix has a changelog entry.
---

# task/c-warnings

## Purpose
The C that chirp owns is compiled with warnings as errors in the shipped build, so a mistake in it stops the build instead of shipping (finding 5).

## Scope
In: `:repo-cflags` in `config.jdn`, applied by `build.janet` to `:repo-sources` (a native's and a target's) in the shipped build; the fixes the flags ask for.
Out: the pins' own sources, which are upstream's; the build machine's compile, whose output does not ship; the generated stub and image C.

## Context & constraints
First pass without -Werror on four targets found two warnings in chirp's code (an unused static in `pcre2.c`, an unused parameter in `gzip.c`) and miniz's unused statics through `gzip.c`'s `#include`. No per-file exemption turned out to be needed, so there is no exemption list; the one excuse is a pragma around the miniz include, which is narrower than a per-file flag. JANET_FN records source lines, so removing lines from a binding moves the binary's hash without changing behaviour.


## Next
CI on the wave branch: five targets twice with matching hashes. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- All five targets build locally with -Wall -Wextra -Werror on the repo's C and no warning from a file under src/; linux-x64 passes all smoke checks. An unused static added to src/omap/omap.c stops the build with 'error: unused function … [-Werror,-Wunused-function]'. Nothing changed behaviour (dead check_start removed from pcre2.c, whose three callers already make the same check inline), so no changelog entry.
- The generated stubs (wasm32-wasi, from tools/build/stub-prelude.c) compile under the same flags; the wasm smoke passes.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
