---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - A .work/-only push to a branch shows a green ci run with checks run and build, compare, smoke and wasm skipped.
  - The same on main leaves pages green with nothing deployed, and the site still serves the last built commit.
  - A code push, a new branch and a release dry run still build everything.
  - A decision records the trade, and main's branch rules are shown not to require a job that the skip would leave unreported.
---

# task/ci-work-only

## Purpose
A push that changes only .work/ gets a green ci run that built nothing, in place of ten cold builds (review finding 4; wanted by BR, 2026-11-24).

## Scope
In: the `changes` job in `ci.yml` and the `needs`/`if` on `build`; `pages.yml`'s plan publishing nothing for a run without artifacts; the release skill's preflight line; the decision.
Out: skipping for anything but `.work/` (docs, the README); caching or reusing artifacts between runs.

## Context & constraints
`ci` is also called by `release.yml` (a tag, or a manual dry run) and by `pages.yml` (a manual run); there the event is the caller's, so those always build. Nothing under `.work/` is read by the build, the smoke checks or the site build. Main's rules were read through the rulesets API (2026-11-24): deletion and non-fast-forward only, no required status checks, which answers the design's branch-rules risk. Design in the milestone's DESIGN.md (U-HM3MZPOZSVLCXGNP), finding 4.


## Next
Push the wave branch (new branch: must build everything), then a .work/-only commit (must skip). After the merge, the same on main with pages. A release dry run (gh workflow run release) must build. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Branch rules: gh api repos/roobie/chirp/rules/branches/main lists deletion and non_fast_forward only, and the branch's required_status_checks are empty with enforcement off, so no rule waits for a skipped job. The trade is D-SBFT5Y7OGHMOVIY6.
- New branch: run 45380990270 on the first push of maintainability-wave-b (ed8e419) has changes green and all ten build jobs started.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
