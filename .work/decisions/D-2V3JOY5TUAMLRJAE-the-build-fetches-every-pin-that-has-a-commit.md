---
status: accepted
date: 2026-10-24
read_if:
  - adding or removing a pin
refs:
  - tools/build/build.janet#fetch
  - pins.jdn
---

# D-2V3JOY5TUAMLRJAE The build fetches every pin that has a :commit

## Context
The build used to keep its own list of what to fetch, beside `pins.jdn`. Adding sqlite3 and tomlin would have meant editing both, and the two lists can drift apart.

## Decision
`pins.jdn` is the single source: every entry that names a commit is fetched.

## Why
A pin with no fetch is dead weight, and a fetch with no pin is not reproducible. Deriving one from the other removes both failure modes. Entries with no commit, such as the container image and zig, are pinned by other means and are skipped.

## Consequences
Adding a source dependency is a one-line edit to `pins.jdn`. A pinned repo the build should not fetch would need its own marker.
