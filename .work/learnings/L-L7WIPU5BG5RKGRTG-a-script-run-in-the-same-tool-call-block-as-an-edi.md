---
date: 2026-11-04
read_if:
  - a chirp script or dev-proc run prints nothing and exits 0
  - a test fails once and never again right after an edit
refs:
---

# L-L7WIPU5BG5RKGRTG A script run in the same tool-call block as an edit to it can read an empty file

## Observation
Twice in one session a dev-proc run printed nothing: once a test failed, once `report` showed no output. Both times the run sat in the same block of tool calls as the edit to `dev-proc.janet`. The calls in a block run at the same time, and the agent harness's edit tool empties the file before writing the new content. A size poller started beside an edit saw the old size, then 0 bytes, then the new size. chirp given an empty script runs no `main`, so it prints nothing and exits 0.

## Why it matters
It looks like a flaky chirp or a flaky test, and can't be reproduced by rerunning, so time goes into chasing a bug that isn't there. A run that depends on an edit belongs in a later block than the edit.
