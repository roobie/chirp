---
status: accepted
date: 2026-11-24
read_if:
  - changing which pushes ci builds for, or the changes job
  - reading a green ci run as proof that a commit was built
  - changing what pages publishes for a ci run
  - making anything under .work/ an input of the build or the site
refs:
  - .github/workflows/ci.yml
  - .github/workflows/pages.yml
---

# D-SBFT5Y7OGHMOVIY6 A push that changes only .work/ gets a green ci run that builds nothing

## Context
Every commit updates `.work/`, and many pushes change nothing else. Each cost ten cold builds and about 20 minutes, for binaries that are byte-identical to the previous push's because nothing under `.work/` reaches the image or the site.

## Decision
The first job of `ci` compares the push with what the branch held before. When every changed file is under `.work/`, the build, compare, smoke and wasm jobs are skipped and the run is green with only `checks` having run. `pages` publishes nothing for a run that has no artifacts. A new branch, a forced push, a pull request, and every call from the release or pages workflow build as before (BR, 2026-11-24).

## Why
`paths-ignore` on the workflow was the alternative. No run would exist then, so the release preflight would have nothing to read and `pages` would never hear of the commit. Reusing the previous run's artifacts to redeploy the site would move only the commit in its footer, at the price of cross-run artifact lookups with retention limits. Asking the API whether the previous run was green, to refuse the skip after a red one, needs `actions: read` in a workflow that the release workflow calls with less, so the job reads only git.

## Consequences
- A green `ci` run no longer always means "built". Its jobs say which: skipped build jobs, and a notice on the `changes` job. The release is unaffected, since a tag's run always builds.
- A `.work/`-only push after a red code push is green although the code it carries is not. The red run stays in the list one line down; read the last run that built before trusting a commit.
- The site's footer and the `latest` tree stay at the last built commit, whose binaries are the same bytes.
- Main has no required status checks (ruleset `protect1` forbids deletion and non-fast-forward only; read 2026-11-24). If required checks are ever added, a skipped matrix job reports under its unexpanded name, so require `checks`, not the build jobs.
- Nothing under `.work/` may become an input of the build, the smoke checks or the site without removing this skip.
