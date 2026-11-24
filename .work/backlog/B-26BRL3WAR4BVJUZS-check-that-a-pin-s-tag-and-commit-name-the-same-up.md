---
created: 2026-11-24
---

# B-26BRL3WAR4BVJUZS Check that a pin's :tag and :commit name the same upstream commit

## Why
A pin in `pins.jdn` has a `:tag`, which versions are read from, and a `:commit`, which is fetched. Nothing checks that the two name the same upstream commit, so a bump that edits one and forgets the other builds the old source under the new version, or the reverse. The chirp-pins skill covers it by hand (step 3 of moving a pin).

## Notes
- A check needs the network (`git ls-remote`), which the build has only while fetching; `tools/pins/watch.janet` already lists the tags and could say when the pinned tag's commit differs from `:commit`.
- Seen while writing the skill, 2026-11-24.
