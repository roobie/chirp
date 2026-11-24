---
phase: initialize
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - main is pushed, and origin has none of dev-proc-no-work-dir-exit, dev-proc-refuse-links, dev-proc-status-json, release-env, main-builds.
  - B-6XHZ4VAU236R34IH is gone, and issue 21 has a backlog item linked on the issue.
  - windows-cancel-tls-read and windows-ca-root-source each have a real Scope and Next or are back in the backlog with their notes, as the owner chose; the untracked voice skill dir is placed or excluded by the owner.
  - The project unit's Evidence holds one line per success criterion plus the latest release, and the chirp-release skill replaces the previous release line.
---

# task/hygiene

## Purpose
Clear the loose ends the review listed, so status, origin and the issue tracker say what is true (review finding 8; the eight steps are in the milestone's PLAN.md).

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Next
<!-- The cursor of the unit being worked: what is about to happen, and for a held unit the reason first.
     Rewrite it freely. A unit with open children keeps none: its present is its children. -->

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 the untracked voice skill dir (SKILL.md and scripts/astra-review.sh) deleted at BR's request; step 6 of the plan is done
