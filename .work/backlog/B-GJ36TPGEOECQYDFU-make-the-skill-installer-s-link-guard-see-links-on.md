---
created: 2026-11-15
---

# B-GJ36TPGEOECQYDFU make the skill installer's link guard see links on Windows

## Why
On Windows Janet's lstat and realpath do not report a link, so the refusal in D-TKUKHE7T3TSZWWSD never fires there, and a forced install can still write through a link to a checkout of the skill.

## Notes
Find a check that works there (reparse points), then drop the Windows exception from the smoke test, the CHANGELOG entry and the decision. The guard is `linked?` in `src/chirp/skills.janet`.
