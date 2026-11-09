---
date: 2026-11-08
read_if:
  - a script needs the path of the running chirp
refs:
  - test/smoke/help-examples.janet
---

# L-ISO5SB2HJ2MWND2S spork/sh/self-exe can return nil on windows

## Observation
On the windows CI runner, `spork/sh/self-exe` returned nil for chirp started by an absolute path, and the tasks example that spawned it failed with "bad slot #0, expected string, got nil". It returns `(dyn *executable*)` only when `path/abspath?` accepts it, and otherwise falls back to `/proc/self/exe` (linux) or a `which` lookup, which found nothing there.

## Why it matters
Code that runs chirp again should pass `(dyn *executable*)`, which `os/spawn` resolves itself. This stops being true if spork's `self-exe` learns windows paths.
