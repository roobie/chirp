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
  - `chirp -h` and `chirp --help` print Janet's option list plus chirp's own additions (`help`, `-`), taken from a help markdown section, and exit 0
  - The smoke suite checks the piped, error and `-` cases; CI is green on all four targets with the double build matching
---

# slice/cli-stdin

## Purpose
Make chirp usable as a pipe target in scripts and by agents (`… | chirp`), and make its own help discoverable from the usual entry points. Today, piped code runs through the interactive REPL. Prompts and echoed values pollute the output, and an error still exits 0, so a failure cannot be detected.

## Scope
In: chirp's dispatch for no arguments, `-`, `-h` and `--help`; the REPL banner; a help markdown section for chirp's command-line additions; smoke checks; a README mention.
Out: changes to Janet's `cli-main` itself; Janet exiting 0 on an unknown flag (upstream behaviour, and a backlog candidate); `-s`, which stays Janet's explicit raw-stdin REPL.

## Context & constraints
- BR asked for this on 2026-10-24, after seeing that piped stdin runs the REPL and errors exit 0.
- `os/isatty` exists in Janet core on both POSIX and Windows (`_isatty`), so terminal detection needs no native code.
- chirp builds on Janet's `cli-main` and does not patch it (D-MNNDC6PNBUNZXT7O), so this goes in chirp's own dispatch ahead of `cli-main`.
- Content is moddable: the text `-h` adds comes from a help markdown section, not from a string in code.
- The bundled-help slice (U-U3CE4WWF4S2GLYDS) touched the same `main.janet`. It is finished in code and only awaits CI and finalize.

## Now
Initialized. Delegating the implementation.

## Next
- Delegate: the dispatch, the banner, the `-h` addition, the help section, the smoke checks and the README. Review, build, push, CI.

## Evidence

## Harvest
- [ ] backlog: Janet's cli-main exits 0 on an unknown flag; consider reporting it upstream or having chirp exit non-zero

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
