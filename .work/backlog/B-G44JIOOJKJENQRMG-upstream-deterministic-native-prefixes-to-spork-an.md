---
created: 2026-10-24
---

# B-G44JIOOJKJENQRMG Upstream deterministic native prefixes to spork and drop the build patch

## Why
Every chirp build carries a patch to a pinned upstream because spork's image prefixes are not deterministic. Upstreaming removes the patch step and the risk of it failing to apply on a spork bump.

## Notes
The patch is in `tools/build/patches`; see the learning on gensym prefixes for the symptom.
