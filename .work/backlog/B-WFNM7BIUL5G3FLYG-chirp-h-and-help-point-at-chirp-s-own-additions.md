---
created: 2026-10-24
---

# B-WFNM7BIUL5G3FLYG chirp -h and --help point at chirp's own additions

## Why
`chirp -h` and `chirp --help` fall through to Janet's `cli-main` and print only Janet's option list. Nothing in that output mentions `chirp help`, `chirp -` or chirp's own `-v`, so a user who reaches for `-h` never finds chirp's docs. BR asked for this as a follow-up to slice cli-stdin (U-XFHE3BIPNBP6KNS5) on 2026-10-24.

## Notes
- Janet's `-h` handler prints and then calls `os/exit 0`, so chirp prints its own part first or handles `-h`/`--help` before `cli-main`.
- The added text is content: take it from a help markdown section, not from a string in code.
- Janet's list includes bundle commands (`-b`, `-u`, `-U`, `-L`, …). Consider whether they make sense for chirp.
- Janet also exits 0 on an unknown flag, after printing the usage. That may belong in the same piece of work.
