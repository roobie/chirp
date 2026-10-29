---
date: 2026-10-29
read_if:
  - a child process run with :e cannot find programs or HOME
refs:
  - test/smoke/dev-proc-install.janet#run
---

# L-6VTNLI3CGMKSPBNU os/spawn :e replaces the whole environment

## Observation
With the `e` flag, the env table passed to `os/spawn` becomes the child's entire environment. Overriding one variable this way drops PATH, HOME and the rest. The smoke test's `run` shows the fix: merge `(os/environ)` first, then apply the overrides. Filed as usage feedback in roobie/chirp#5.

## Why it matters
Any script or test that sets a few variables for a child process, such as HOME for a `-g` install, will fail in confusing ways unless it merges. This stays true for as long as Janet's `os/spawn` keeps these semantics.
