---
created: 2026-10-24
---

# B-JSN4UWUJCBBNOWEX Run leakcheck all and its tests in CI

## Why
Hooks can be skipped (`--no-verify`, or a clone without `core.hooksPath`). A CI run of `leakcheck all` plus `tools/leakcheck/test.janet` catches what gets past them, using the generic rules.

## Notes
Add this when the GitHub CI is set up (D-URDDGCK3H3MPSCTM).
