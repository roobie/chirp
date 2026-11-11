---
created: 2026-11-11
---

# B-NYH6ZSXTHFNZJI42 Make --help print usage for every dev-proc command

## Why
Since unknown flags became usage errors, `<cmd> --help` exits 2 on every command but find and report, which print their own usage. Someone typing `--help` wants usage, not an error.

## Notes
- Accept `help` for every command (like ENV-OPTIONS), printing the command's own usage where it has one and HELP otherwise.
