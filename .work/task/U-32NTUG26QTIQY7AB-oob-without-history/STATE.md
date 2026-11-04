---
phase: execute
parent: U-UETNG3AZPMSATKY2
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - SKILL.md says the Every commit, close-commit and Archaeology rules apply to team roots, and what holds for an out-of-band one
  - close in a root without history (not in a git repo, or git-ignored in it) moves the unit dir to <root>/closed/<type>/ instead of deleting it; a root with history still deletes
  - record --supersedes in a root without history moves the old decision to <root>/closed/decisions/ instead of deleting it
  - dig in a root without history prints the unit or record from <root>/closed/; status, find and check ignore closed/
  - tests, help and CHANGELOG cover it; the dev-proc test suite passes
---

# task/oob-without-history

## Purpose
An out-of-band root is told apart from team roots in SKILL.md, and one without git history keeps what close and record --supersedes would delete.

## Scope
In: SKILL.md wording; a has-history test for a root; close and record --supersedes archiving to <root>/closed/; dig reading closed/; tests, help, CHANGELOG.
Out: running outside a git repo (task no-git-repo).

## Context & constraints
- A root has history when its dir is inside a git work tree and not git-ignored there; an out-of-band root in a repo of its own has history, one git-ignored in the team repo has none.
- load-root reads only the type dirs and record dirs, so a closed/ dir is invisible to status, find and check without extra code.


## Now
Criteria met; ready to finalize.

## Next
- finalize: record the decision and the backlog item, close

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- history-top decides; close and record --supersedes archive to <root>/closed/ in a root without history (outside any repo, or git-ignored); dig reads closed/ through work-path; status/find/check never see closed/ since load-root reads only type and record dirs
- tests: 'a root without git history keeps closed units and superseded records in closed/' and 'a git-ignored root in the repo has no history; one in a repo of its own does'; chirp dev-proc.test.janet, find and frontmatter suites all pass
- SKILL.md scopes Every commit to team roots and adds a No history bullet; close help and CHANGELOG updated

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: a work dir without git history archives closed units and superseded records in closed/ rather than deleting them or refusing to close
- [ ] backlog: offer the closed/ archive and the out-of-band Supersedes fix upstream to spartan's dev-proc (D-VZIDK5O2VNATQDCP)

## Log
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
- 2026-11-04 record --supersedes stopped printing a Supersedes: trailer for out-of-band roots, which D-6RKLCVKL6N2QK75E already said they never name
