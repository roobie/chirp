---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-02
success_criteria:
  - 'release.yml has a tag-only job, after publish, holding only issues: write, that closes milestone X.Y.Z''s open issues with a link to the release and then the milestone; a version with no milestone is not an error'
  - Its queries are checked read-only against milestone 0.7.0, and actionlint/shellcheck pass if available
  - The first live run is the 0.7.0 release; checking that it closed
---

# task/release-closes-milestone

## Purpose
Publishing vX.Y.Z closes the open issues on milestone X.Y.Z with a comment linking the release, then closes the milestone, so landed issues close when they ship.

## Scope
In: a close-milestone job in release.yml.
Out: tagging (D-MB5WIOASYBDI7AEB keeps it manual); the leftover open 0.5.0 milestone, which has no open issues and is for BR to close by hand.

## Context & constraints
Only publish may write contents (release.yml comment); the new job gets issues: write and nothing else. Prereleases carry a suffix and so match no milestone.

### Origin
Promoted from backlog: B-JYF7PEJG4OH36UFJ Release workflow closes its milestone's issues

### Why
BR wants an issue that has landed on main to close when the release carrying it ships, not before. Issue #2 is the first one in that state: it is on milestone 0.5.0 and still open. Closing such issues by hand is easy to forget.

### Notes
release.yml runs on a tag and does not touch issues today. One option: on publishing vX.Y.Z, close the open issues on milestone X.Y.Z with a comment linking the release, then close the milestone.


## Now
Done; the job first runs at the 0.7.0 tag.

## Next
- Finalize; the project's Next carries the check at 0.7.0

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- The workflow parses (yaml/decode lists close-milestone after publish); shellcheck passes on its script. Read-only against roobie/chirp: the milestone lookup gives 2 for 0.7.0 and nothing for 9.9.9; the issue query gives 7 and 5.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-02 initialized
- 2026-11-02 phase initialize → execute
- 2026-11-02 close-milestone job in release.yml
