---
date: 2026-10-25
read_if:
  - dev-proc or its commit hooks fail at import
refs:
  - .agents/skills/dev-proc/scripts/frontmatter.janet#decode-fm
---

# L-NYRT2RGVVAXTFIOF dev-proc needs a chirp that bundles omap

dev-proc reads front matter with the ordered yaml decode, so it imports `omap`. A chirp older than 0.3.0 has no omap, and dev-proc then fails at import, which makes the commit hooks fail as well. The fix is a newer chirp on PATH, not a change to dev-proc. A branch that changes chirp's modules can be committed with that branch's own build first on PATH.
