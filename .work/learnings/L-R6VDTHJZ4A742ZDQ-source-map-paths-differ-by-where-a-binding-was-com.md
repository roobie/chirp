---
date: 2026-10-29
read_if:
  - mapping a binding's source-map to a file
  - a binding shows no source in chirp --help read --source
refs:
  - src/chirp/source.janet#locator
---

# L-R6VDTHJZ4A742ZDQ source-map paths differ by where a binding was compiled

## Observation
A binding's `:source-map` file is whatever path its compiler saw, so the form differs by origin:
- boot.janet: a bare name
- Janet core's C: relative to the janet tree
- spork and other fetched modules: relative to the build out dir
- chirp's overlays: absolute, at the container's repo mount
- chirp-owned natives: `./src/…`

The rules in chirp.jdn's `:help-source` cover each form.

## Why it matters
A build run outside the container has a different overlay path, so overlays show no source there. CI and release builds are unaffected. A change to how a module is fetched or compiled can quietly drop its source, and the smoke checks for `--source` are what catch it.
