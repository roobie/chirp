---
date: 2026-10-27
read_if:
  - leakcheck flags an env-secret-name in a workflow
  - passing a GitHub token to a step
refs:
  - tools/leakcheck/leakcheck.janet
  - .github/workflows/pages.yml
---

# L-EGSSVSI3WKR7ORNR leakcheck flags a workflow's token variable when the committing host exports that name

## Observation
leakcheck adds the name of every secret-looking env var set on the committing host to its needles, and allow.jdn deliberately cannot exempt this host's values, since the exemption would itself commit them. On a host that exports gh's token variable, any staged workflow that names it fails the commit, even though in a workflow it only means the run's own token. pages.yml passes `github.token` as an action input (`github-token:`) instead.

## Why it matters
Prefer action inputs over env vars for tokens in new workflows. release.yml already uses gh this way, so a change to it fails the hook on such a host. It stops applying if leakcheck learns to tell names from values.
