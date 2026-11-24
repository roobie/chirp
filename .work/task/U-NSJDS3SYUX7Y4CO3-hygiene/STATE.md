---
phase: execute
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
In: the eight steps under task `hygiene` in the milestone's PLAN.md (U-HM3MZPOZSVLCXGNP): push main, delete merged branches on origin, drop the stale backlog item, give issue 21 a backlog item, settle the two stalled windows tasks and the untracked skill dir with the owner, trim the project unit's Evidence, note the stale installed chirp.
Out: fixing issue 20 (task skill-install-parent-links, wave C) or issue 21; doing the two windows tasks.

## Context & constraints
Steps 5 and 6 are the owner's decisions; step 6 was decided on 2026-11-24 (delete). Step 8 changes a machine, not the repo.


## Next
Step 5 waits for the owner: give windows-cancel-tls-read and windows-ca-root-source a real Scope and Next, or return them to the backlog with their notes. Step 8 is a note for whoever works on a machine whose installed chirp is older than the last release (this one runs 0.13.0-dev). Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Step 2: origin now has only main and the wave's branch. dev-proc-no-work-dir-exit, dev-proc-refuse-links, dev-proc-status-json and release-env were ancestors of main; main-builds' tip 8fa7544 was the merge of pull request 13, both parents in main and its tree equal to their automatic merge (428a5a03), so nothing was only there.
- Step 3: B-6XHZ4VAU236R34IH deleted; no unit carries a '## Now' and check is clean.
- Step 4: B-IRCVVXCJX6GVYOES records issue 21, and the issue links it (comment 7128332466). Issue 20 is wave C's task.
- Step 6: the untracked voice skill dir was deleted at the owner's request (2026-11-24).
- Step 7: the project unit's Evidence is 6 criterion lines plus the 0.13.1 release line (was 30 lines); the provenance line was re-checked with gh attestation verify. The chirp-release skill now replaces the release line instead of appending.
- Step 1: main fast-forwarded to the wave's branch at c29ef43 and pushed; the branch is deleted, so origin has only main.

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
- 2026-11-24 phase initialize → execute
