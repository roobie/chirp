---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - src/chirp/paths.janet holds the OS test, the directory of a path and the directory of the file being compiled, with a test beside it; ca, update, skills, repl, main and the https overlay use it and define none of their own.
  - rg shows one windows? definition and one directory-of-path helper under src/chirp; src/tar/tar.janet and the smoke scripts keep theirs.
  - Smoke is green on all four native runners, windows included.
---

# task/path-helpers

## Purpose
src/chirp has one OS test and one directory-of-path helper, so the next caller cannot pick the variant that forgets a backslash (review finding 7).

## Scope
In: `src/chirp/paths.janet` with its test; `ca`, `update`, `skills`, `repl`, `main` and the https overlay moved to it.
Out: `src/tar/tar.janet`, a public module that takes nothing from chirp's internals; the smoke scripts, which each stand alone (D-DPSCZ2KCZA4UB7YM); the link check of issue 20 (task skill-install-parent-links, wave C).

## Context & constraints
The OS test stays a function, because the image is built on linux for every target (L-J2G76CUIQU4OWGMK). `update.janet`'s `dir-of` is the one that already splits on either separator on windows, so it is the one kept. Design in the milestone's DESIGN.md (U-HM3MZPOZSVLCXGNP), finding 7.


## Next
Push with the rest of wave B; smoke must be green on the four native runners, windows above all. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- rg 'defn-? (windows\?|dir-of|dirname)' src/chirp finds only paths.janet's two; main and the overlay take 'here' from paths/source-dir. paths.test.janet passes (11 dir-of cases, either separator on windows).
- linux-x64 built locally passes all 26 smoke checks. windows-x64 built locally and run under Wine with the checkout mounted passes 25 of 26: ca-roots writes its bundle through paths/dir-of under AppData, self-update and the skill install pass; dev-proc-install then fails at 'git init' because the Wine image has no git.exe, which the old code would also do.
- ci run 45380990270 (ed8e419): smoke on windows-x64, macos-arm64, linux-arm64 and linux-x64 each print 26 checks ok; on the windows runner ca-roots writes its bundle under AppData (413 roots), dev-proc-install and self-update pass.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] backlog: test/smoke/run-windows.sh cannot go green under Wine: dev-proc-install runs git, which the Wine image lacks; it also mounted only test/smoke, so two checks could not find the source tree (the mount is fixed here)

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
