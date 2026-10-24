---
phase: initialize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A script run by the chirp binary on a host with no SQLite installed creates a database file, writes rows and reads them back via (import sqlite3)
  - The double-build sha256 check still passes with sqlite3 included
---

# slice/bundle-sqlite

## Purpose
Make SQLite available from the single static binary (D-Z7JOCFPGMOANQFY7), so scripts can keep local state with nothing installed.

## Scope
In: a janet-lang/sqlite3 pin; one entry in the build's data list of native modules; a smoke check.
Out: SQLite compile-time feature tuning beyond upstream defaults; any ORM or helper layer.

## Context & constraints
- Depends on slice U-34F3JPNU2EK44A7I (linux-x64-spike), which sets up the data list of native modules and the build.
- Compression is already covered by spork/zip within the spike (D-AD6YBCGFHJTVZ7TZ).

## Now
Waiting for the spike to deliver the build.

## Next
- Pin janet-lang/sqlite3, add its native module entry, add the smoke check.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
