---
status: accepted
date: 2026-11-02
read_if:
  - changing how bare chirp starts its REPL
  - moving the janet pin (compare cli-main's REPL branch)
refs:
  - src/chirp/repl.janet#run
  - test/smoke/repl.janet#session
---

# D-MK7YV2MMJT7324MV The interactive REPL mirrors cli-main's with spork/getline as its line reader

## Context
Stock janet edits REPL lines with a getter from its shell (`mainclient/shell.c`), which it swaps in for `getline` when it builds its core environment. chirp's executable unmarshals its image against the plain core environment, so `cli-main` reads bare lines: no history, no cursor keys, no completion. `cli-main` takes no getter, and D-ZBIADZDYXYPWLX5L rules out patching janet.

## Decision
Bare `chirp` on a terminal runs chirp's own copy of `cli-main`'s REPL branch, with the bundled spork/getline reading lines. Where the terminal has no room for the prompt (or reports no width), Janet's plain `getline` reads the line instead, because spork/getline fails there.

## Why
Compiling `shell.c` in with its `main` renamed would give janet's exact editor, but means building a file meant as a program and depending on its internals. A C getter of our own would duplicate spork/getline. Copying the REPL branch costs about fifteen lines that can drift from `cli-main`; spork/getline is already bundled and also backs spork/netrepl.

## Consequences
When the janet pin moves, compare `cli-main`'s REPL branch (environment variables, colour, prompt, profile) with `repl.janet`. Other ways into a REPL, such as `chirp -r` or `chirp -e ... -r`, still go through `cli-main` and read bare lines. Ctrl-C at the prompt exits with status 1, as spork/getline does.
