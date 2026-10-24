---
phase: initialize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A script run by the chirp binary on a host with no SQLite installed creates a database file, writes rows and reads them back via (import sqlite3)
  - A script run by the chirp binary parses a TOML file via (import tomlin) with no files on disk besides the script and its input
  - The double-build sha256 check still passes with both included
---

# slice/bundle-sqlite-toml

## Purpose
Make SQLite (D-Z7JOCFPGMOANQFY7) and TOML reading (D-DMR3ULVUY2KA72XN) available from the single static binary, so scripts can keep local state and read config with nothing installed.

## Scope
In: janet-lang/sqlite3 and pyrmont/tomlin pins; a native module entry for sqlite3 and a pure module entry for tomlin in the build's data lists; a smoke check for each.
Out: SQLite compile-time feature tuning beyond upstream defaults; any ORM or helper layer; a TOML encoder.

## Context & constraints
- Depends on slice U-34F3JPNU2EK44A7I (linux-x64-spike), which sets up the data lists of modules and the build.
- Compression is already covered by spork/zip within the spike (D-AD6YBCGFHJTVZ7TZ).

## Now
Waiting for the spike to deliver the build.

## Next
- Pin janet-lang/sqlite3 and pyrmont/tomlin, add their module entries, add the smoke checks.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 rescoped slice/bundle-sqlite → slice/bundle-sqlite-toml
- 2026-10-24 TOML added to scope by BR
