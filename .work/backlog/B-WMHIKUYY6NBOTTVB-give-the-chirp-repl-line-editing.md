---
created: 2026-10-24
---

# B-WMHIKUYY6NBOTTVB Give the chirp REPL line editing

## Why
The chirp REPL has no history or cursor movement, because stock janet's line getter is not available to a custom executable. Interactive use feels worse than plain janet.

## Notes
spork/getline is already bundled and may serve as the getter.
