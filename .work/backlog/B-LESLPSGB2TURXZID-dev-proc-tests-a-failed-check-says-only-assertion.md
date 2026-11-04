---
created: 2026-11-04
---

# B-LESLPSGB2TURXZID dev-proc tests: a failed check says only "assertion failed"

## Why
In the work-dir-name slice the --help test failed once and passed in six reruns. The message gave no line or value, so the cause is unknown. A check helper that names the call site or the compared values would have caught it in one run.

## Notes
TODO
