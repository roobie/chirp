---
created: 2026-10-30
---

# B-DDPZPOA7SAX5D6LX dev-proc parse-args: a -- terminator so note text can start with --

## Why
`note <unit> log "--force was needed"` reads the text as a flag, so a note about a flag can't be written as the user typed it. Found while building `note` in slice dev-proc-ergonomics.

## Notes
- The usual fix is `--` ending flag parsing, as in most CLIs.
