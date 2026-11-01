---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-01
success_criteria:
  - A smoke check runs os/execute and os/spawn with :cd and sees the child in that directory, with the parent's cwd unchanged, on each target's native runner in a CI run that builds all four targets twice with matching sha256
  - test/smoke/dev-proc-install.janet uses :cd instead of os/cd
  - chirp --help query 'subprocess working directory' finds a topic covering :cd and merging os/environ under :e
  - 'CHANGELOG.md Unreleased lists the fix with #5'
---

# slice/spawn-cd

## Purpose
Make (os/spawn … {:cd dir}) and os/execute's :cd work in chirp on every target, so a script can run a subprocess in another directory without os/cd (#5).

## Scope
In: turn on Janet's existing `:cd` spawn option for the linux targets through a build define; a smoke check on all four targets; the dev-proc-install smoke check drops its `os/cd` workaround; a help topic on running subprocesses (`:cd`, and `:e` replacing the environment); a changelog entry citing #5.
Out: patching janet (D-ZBIADZDYXYPWLX5L); an overlay on spork/sh (it takes no env table at all; a separate question for BR); the upstream report itself, which is a harvest item.

## Context & constraints
- The pinned janet (dc0f243b) already has `:cd` in the env table of os/execute and os/spawn (upstream 3edc4f35, 2025-04-06), but os.c only defines `JANET_SPAWN_CHDIR` for windows, glibc, macOS ≥10.15 and FreeBSD. musl has `posix_spawn_file_actions_addchdir_np` (≥1.1.24) but no macro to detect it, so chirp's static musl linux builds panic: `:cd argument not supported on this system`.
- windows defines `JANET_SPAWN_CHDIR` unconditionally; macOS builds with min 11.0 and os.c includes AvailabilityMacros.h, so both should already work. The smoke check proves it.
- Build defines today reach only the natives (`:defines`); janet.c gets `:cflags`. A janet-only define needs its own key so the windows natives' defines do not leak into janet.c.
- Reproducibility (D-Q23RA2EVVN5LYCX7) and smoke-check rules (D-DPSCZ2KCZA4UB7YM) apply.

## Now
Fix, smoke check, help topic and changelog done and green locally (linux-x64); waiting on a CI run for all four targets.

## Next
- Push and get a ci run: all four targets twice with matching sha256, spawn-cd and help smoke checks green on each native runner
- Reply on #5 (Fixes in 0.7.0; spork/sh takes no options, os/spawn covers it) and put it on milestone 0.7.0
- File the two upstream janet reports from Harvest, if BR agrees

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Negative control: the installed 0.7.0-dev (pre-fix) fails test/smoke/spawn-cd.janet with `:cd argument not supported on this system`, the error from #5.
- Local linux-x64 build (tools/build/container.sh, sha256 fa610c80…) passes the full smoke suite, spawn-cd, dev-proc-install on :cd, and the help query for the subprocess topic included.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] learning: musl has posix_spawn_file_actions_addchdir_np but no macro to detect it, so janet's os.c leaves :cd off on musl; JANET_SPAWN_CHDIR turns it on
- [ ] backlog: propose upstream that janet enable :cd on musl linux (or all linux) and document :cd in the os/execute and os/spawn docstrings; then drop chirp's :janet-defines
- [ ] backlog: propose upstream that janet's posix_spawn failure report the returned status, not errno (a missing :cd dir says `Not a tty`); then drop that sentence from help/subprocess.md

## Log
- 2026-11-01 initialized
- 2026-11-01 phase initialize → execute
- 2026-11-01 build define, spawn-cd smoke check, dev-proc-install on :cd, help topic subprocess, changelog; green locally
