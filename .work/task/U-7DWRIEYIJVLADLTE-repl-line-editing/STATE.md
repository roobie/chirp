---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-02
success_criteria:
  - In a terminal, Up recalls the previous line and Left moves the cursor; a smoke check drives this through a pty on linux
  - A terminal reporting no width still reads lines, and JANET_PATH, JANET_PROFILE, NO_COLOR and *repl-prompt* behave as before
  - CI builds all four targets twice with matching sha256 and the smoke checks pass
---

# task/repl-line-editing

## Purpose
Bare chirp on a terminal gives a REPL with history, cursor movement, tab completion and Ctrl-G docs, as plain janet does.

## Scope
In: src/chirp/repl.janet run from bare chirp on a terminal, a pty smoke check through util-linux script, help text, changelog, decision.
Out: the REPLs that cli-main starts for flags such as -r; fixing spork/getline itself.

## Context & constraints
spork/getline and spork/rawterm are bundled. Piped stdin keeps running as a script (main.janet run-stdin). D-ZBIADZDYXYPWLX5L: no janet patch.

### Origin
Promoted from backlog: B-WMHIKUYY6NBOTTVB Give the chirp REPL line editing

### Why
The chirp REPL has no history or cursor movement, because stock janet's line getter is not available to a custom executable. Interactive use feels worse than plain janet.

### Notes
spork/getline is already bundled and may serve as the getter.


## Now
Done locally; waiting on CI.

## Next
- Push, check the CI run, finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- test/smoke/repl.janet fails with the installed chirp (Up arrives as ^[[A, parse errors) and passes with a local linux-x64 build, as does the full smoke suite. Checked by hand in a pty: Tab completes user defs, Ctrl-G shows docs, JANET_PROFILE prompt and JANET_PATH imports work, Ctrl-C exits 1.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] backlog: spork/getline fails (rawterm/slice-monowidth, negative width) when the terminal is narrower than the prompt or reports no width; file upstream at janet-lang/spork

## Log
- 2026-11-02 initialized
- 2026-11-02 phase initialize → execute
- 2026-11-02 chirp-owned REPL with spork/getline; plain getline when there is no width; pty smoke check; decision D-MK7YV2MMJT7324MV
