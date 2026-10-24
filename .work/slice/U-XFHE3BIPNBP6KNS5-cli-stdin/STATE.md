---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - Piping code into a bare `chirp` (stdin not a terminal) runs it as a script. Output has no banner, no prompts and no echoed values, and the exit status is 0
  - A top-level error in piped code prints the error to stderr and exits non-zero
  - `chirp - a b` runs stdin as a script whatever stdin is, and the script's `main` receives `-`, `a`, `b`
  - Bare `chirp` on a terminal still starts the REPL, and its banner points at `chirp help`
  - The smoke suite checks the piped, error and `-` cases; CI is green on all four targets with the double build matching
---

# slice/cli-stdin

## Purpose
Make chirp usable as a pipe target in scripts and by agents (`… | chirp`), and make its own help discoverable from the usual entry points. Today, piped code runs through the interactive REPL. Prompts and echoed values pollute the output, and an error still exits 0, so a failure cannot be detected.

## Scope
In: chirp's dispatch for no arguments and for `-`; the REPL banner; the help text for piped and `-` use; smoke checks; a README mention.
Out: changes to Janet's `cli-main` itself; `-s`, which stays Janet's explicit raw-stdin REPL. `-h`/`--help` and the unknown-flag exit status are follow-up B-WFNM7BIUL5G3FLYG (BR, 2026-10-24).

## Context & constraints
- BR asked for this on 2026-10-24, after seeing that piped stdin runs the REPL and errors exit 0.
- `os/isatty` exists in Janet core on both POSIX and Windows (`_isatty`), so terminal detection needs no native code.
- chirp builds on Janet's `cli-main` and does not patch it (D-MNNDC6PNBUNZXT7O), so this goes in chirp's own dispatch ahead of `cli-main`.
- The bundled-help slice (U-U3CE4WWF4S2GLYDS) touched the same `main.janet`. It is finished in code and only awaits CI and finalize.

## Now
Initialized. Delegating the implementation.

## Next
- Delegate: the dispatch, the banner, the help text, the smoke checks and the README. Review, build, push, CI.

## Evidence
- Two linux-x64 builds, run one after the other, have the same `bin/chirp` sha256 (8cbb73de…f59c3e, 9053512 bytes). The smoke suite passes, `ok stdin` included.
- Piped `(print "hi")` prints `hi` and exits 0. Piped `(error "boom")` exits 1 with the error on stderr. `chirp - a b` gives main `-,a,b`. `true | chirp` prints nothing and exits 0. Piped `(+ 1 2)` echoes nothing. A piped `main` that errors exits 1.
- The terminal REPL path was checked only by reading the code: it is the previous `cli-main @["-q"]` call, with the banner suffix changed.

## Harvest
- [ ] learning: Janet's run-main is private, so chirp's stdin path mirrors it (main.janet#run-stdin); re-check it on Janet pin bumps

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
