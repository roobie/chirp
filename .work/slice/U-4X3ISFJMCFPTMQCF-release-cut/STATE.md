---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-30
success_criteria:
  - tools/release/cut.janet X.Y.Z turns a -dev main into the release commit's files (version, changelog heading and date, README version example) and refuses off main, with a dirty tree, or with an empty Unreleased section
  - tools/release/cut.janet --next moves a released version to the next minor -dev with an empty Unreleased section
  - A test covers both modes and the refusals, and CI runs it
  - A decision record says why the tag stays a manual step
---

# slice/release-cut

## Purpose
Cutting a release and moving main to the next -dev were hand edits from memory notes. A script makes them one command each, so the steps live in the repo as code and can't drift between hosts or agents.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
Script, test, CI line and decision are in; waiting for CI to run the test

## Next
Finalize once CI is green; shrink the release memory to point at the script

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- tools/release/cut.test.janet passes locally under env -i: both release cases with exact file contents, both --next cases, and eight refusals that leave files unchanged; a dry run on copies of the real files gave 0.7.0, then 0.8.0-dev
- D-MB5WIOASYBDI7AEB records why the tag stays manual

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-10-30 initialized
- 2026-10-30 phase initialize → execute
- 2026-10-30 script, test and decision written
