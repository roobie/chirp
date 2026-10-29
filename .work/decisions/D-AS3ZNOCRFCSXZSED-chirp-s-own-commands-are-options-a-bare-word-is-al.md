---
status: accepted
date: 2026-10-29
read_if:
  - adding a chirp command or flag
  - a script name collides with a chirp command
refs:
  - src/chirp/main.janet#main
  - src/chirp/help.janet#run
---

# D-AS3ZNOCRFCSXZSED chirp's own commands are options; a bare word is always a script

## Context
Issue #3. `help` and `self-update` were bare-word subcommands, so a script with either name could not be run as `chirp <name>`, and the CLI mixed bare words with `--changelog` and `--dev-proc`. Janet's options are single letters and Janet reads any `--…` as end of options, so long `--` names are free for chirp.

## Decision
Every chirp entry point is an option. Offline help hangs off `-h`/`--help` (with `query` and `read` after it), and the updater is `--self-update`. Any first argument that is not an option goes to Janet as a script.

## Why
BR picked `--help` taking words over a separate `--docs` flag, or top-level `--query`/`--read` flags: it gives one entry point for help and keeps the words people already knew. The old words were dropped without a hint or a deprecation period, because nobody but BR ran 0.2.0–0.4.0. A fallback would have kept the collision from #3 alive, and it would have been debt to remove later.

## Consequences
A new chirp command must be a `--` name that no Janet option or bundled skill already takes. A bare word can never be added as a command again.
