---
created: 2026-10-25
---

# B-QCBMFCPRFJGNUXAH Benchmark chirp against Python and Node on common scripting tasks

## Why
The README pitches chirp against Python and shell for everyday scripts. BR wants numbers behind that claim (2026-10-25), and a perf baseline would show whether a bundled module or a bump of a pin slows chirp down.

## Notes
- Candidate tasks: start-up and a trivial script; reading and writing JSON; an HTTPS GET; SQLite inserts and an FTS query; parsing TOML; spawning subprocesses; walking a directory tree; regex over a large text file.
- Measure wall time and peak memory with hyperfine or similar, on the same machine and with warm caches. Report both start-up and steady-state cost, since scripts are often short-lived.
- Compare against stock CPython and Node, each using its usual libraries for the job (requests or urllib, the sqlite3 module, tomllib; fetch and node:sqlite).
- Open questions: whether it runs in CI, which would need stable runners, or by hand per release; and where results live (a doc, or a help topic).
