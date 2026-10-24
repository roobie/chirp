---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A script run by the chirp binary on a host with no SQLite installed creates a database file, writes rows and reads them back via (import sqlite3)
  - A script run by the chirp binary parses a TOML file via (import tomlin) with no files on disk besides the script and its input
  - The double-build sha256 check still passes with both included
  - Every target's NOTICES.txt carries the sqlite3 binding, SQLite and tomlin texts, and the README lists both components
  - CI is green on all four targets, with the new smoke checks run on each target's native runner
---

# slice/bundle-sqlite-toml

## Purpose
Make SQLite (D-Z7JOCFPGMOANQFY7) and TOML reading (D-DMR3ULVUY2KA72XN) available from the single static binary, so scripts can keep local state and read config with nothing installed.

## Scope
In: janet-lang/sqlite3 and pyrmont/tomlin pins; a native module entry for sqlite3 and a pure module entry for tomlin in the build's data lists; a smoke check for each; their notices and README rows.
Out: SQLite compile-time feature tuning beyond upstream defaults; any ORM or helper layer; a TOML encoder; the 0.2.0 version bump and release (a later slice).

## Context & constraints
- The build (linux-x64-spike, build-matrix) is delivered; 0.1.0 shipped without these two (BR).
- Compression is already covered by spork/zip (D-AD6YBCGFHJTVZ7TZ).
- Pins found 2026-10-24: janet-lang/sqlite3 at 9126fe46ff1c7e42ca3d7bb9c8aed95a8236a32c (vendors SQLite 3.53.3; binding MIT), pyrmont/tomlin at 3ed6587e8460af4d2e7fcc2a40dd7591e07a953d (MIT).
- The image resolves pinned Janet sources by `src/<pin>/:all:.janet`, but tomlin's entry is its root `init.janet`, so `(import tomlin)` needs a resolution rule for it.
- SQLite is public domain and the amalgamation ships no license file, so its notice is a repo-supplied text, as for jsec (D-KPP2PSBZKFSROC44).
- Every new bundled module can break the double-build check (L-AGD7ZVHWYRGFIEDF). Any config.jdn edit moves the hashes on its own (B-U6C4GF5ICCTMVVBL), so hash changes are expected; only copy a vs copy b agreement counts.

## Now
Change reviewed. linux-x64 builds and passes smoke locally; push and watch CI.

## Next
- Get CI green on all four targets, then finalize.

## Evidence
- Local linux-x64 build (Docker, 2026-10-24): `test/smoke/run.janet` passes every check, including `ok sqlite3 3.53.3` and `ok toml 5 keys`. The binary is 8555656 bytes; 0.1.0 was 7381448.
- That build's NOTICES.txt carries the janet-lang/sqlite3 binding, SQLite (the blessing, https://sqlite.org/copyright.html) and tomlin. The README table lists both components.
- `leakcheck staged` is clean.

## Harvest
- [ ] decision: a Janet library whose entry point is not `<name>.janet` gets bundled through a `:janet-modules` data entry in config.jdn, not a special case in image.janet
- [ ] decision: the build fetches every pin that has a `:commit`, so adding a pin needs no change to build.janet

## Log
- 2026-10-24 initialized
- 2026-10-24 rescoped slice/bundle-sqlite → slice/bundle-sqlite-toml
- 2026-10-24 TOML added to scope by BR
- 2026-10-24 phase initialize → execute
