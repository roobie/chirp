---
created: 2026-10-25
---

# B-IRERZRV2753OHW3R Gaps met porting dev-proc to chirp

## Why
Porting dev-proc from Node was meant to find what chirp lacks for everyday scripts. These are the gaps it hit. They were not filed as issues, because BR asked for no GitHub issues for now.

## Notes
- `os/spawn` has no working-directory option, and its env table is also the stdio table, so passing `:e` replaces the whole environment.
- There is no recursive mkdir and no mktemp.
- There was no JSON object that keeps key order; slice U-F7D455PIPRC3AXFQ added `omap` and ordered json and yaml (D-PYFZFKJPCW3QPOTB).
- FTS5 ships no stopword list.
- Core surprises a helper module or the docs could cover:
  - `sort` is not stable.
  - `string/trim` also trims NUL.
  - `string/join` and `peg/replace-all` return buffers, which `os/spawn` rejects.
  - `ev/read … :all` returns nil on empty output.
- Decide per item whether chirp should fix it, document it or leave it, and file issues once that is allowed again.
