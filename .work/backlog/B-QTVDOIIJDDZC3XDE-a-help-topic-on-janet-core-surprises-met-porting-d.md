---
created: 2026-11-08
---

# B-QTVDOIIJDDZC3XDE A help topic on Janet core surprises met porting dev-proc

## Why
Porting dev-proc from Node (B-IRERZRV2753OHW3R) hit core behaviour that cost time because nothing pointed it out. A chirp help topic, or a short section in an existing one, would save the next script author the same hunt. chirp does not patch Janet's core (D-MNNDC6PNBUNZXT7O), so documenting is chirp's side; any fix is upstream's.

## Notes
- `sort` and `sort-by` are not stable.
- `peg/replace-all` returns a buffer, which `os/spawn` rejects as an argument.
- `ev/read … :all` returns nil on empty output.
- There is no mktemp; spork/sh has `create-dirs` for recursive mkdir.
- FTS5 ships no stopword list (dev-proc carries its own in .agents/skills/dev-proc/scripts/find.janet).
- Checked on 0.9.0: `string/trim` keeps NUL and `string/join` returns a string, so those two from the old list were dropped.
- Already covered elsewhere and dropped from the old list: os/spawn's `:cd` and `:e` (src/chirp/help/subprocess.md, L-6VTNLI3CGMKSPBNU) and ordered JSON and YAML (D-PYFZFKJPCW3QPOTB).
