---
created: 2026-10-29
---

# B-JYF7PEJG4OH36UFJ Release workflow closes its milestone's issues

## Why
BR wants an issue that has landed on main to close when the release carrying it ships, not before. Issue #2 is the first one in that state: it is on milestone 0.5.0 and still open. Closing such issues by hand is easy to forget.

## Notes
release.yml runs on a tag and does not touch issues today. One option: on publishing vX.Y.Z, close the open issues on milestone X.Y.Z with a comment linking the release, then close the milestone.
