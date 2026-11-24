---
created: 2026-11-24
---

# B-U5HBAYTD4MV6TFH5 run-windows.sh cannot pass under Wine: dev-proc-install needs git

## Why
`test/smoke/run-windows.sh` is the only way to run the windows build before pushing, and it cannot go green: `dev-proc-install` runs `git init`, and the Wine image has no `git.exe`. Seen 2026-11-24 in task path-helpers, where the other 25 checks passed under Wine once the whole checkout was mounted.

## Notes
- Either the check skips its last part when no git is on the PATH and says so, as `repl` does without util-linux `script`, or the Wine image gets a windows git.
- The script also builds twice and compares before it runs anything; a single already-built `bin/` cannot be passed in.
