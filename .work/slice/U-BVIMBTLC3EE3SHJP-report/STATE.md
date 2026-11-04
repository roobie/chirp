---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - dev-proc report [<range>] [--since <date>] [--json] summarises units (delivered, scrapped, open, with type/name, commit count and parent) and record counts (+added −removed per kind)
  - with no range it covers the last tag..HEAD, or all history when there is no tag
  - everything comes from git; no new state is stored; dig and report share how paths are recognised
  - tests, SKILL.md, help and CHANGELOG cover it
---

# slice/report

## Purpose
Give the operator a short overview of the dev-proc work done over a stretch of git history: which units were delivered, scrapped or left open, how many commits each took, and the records harvested.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
implemented and tested; finalizing

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- dev-proc.test.janet report test: last-tag default, delivered/scrapped (Decision: trailer)/open, a rescope counted as neither start nor close and labelled by its new name, parents, record counts, <rev> meaning <rev>..HEAD, JSON, no-tag fallback, bad range error; all suites pass
- on this repo: report gives v0.7.0..HEAD in 0.4s over the whole 160-commit history; units named only by old trailers show (no STATE.md in history)
- dig and report share work-path for recognising unit and record paths; trailer-values generalises work-trailers for Decision:

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] process: report printed nothing once on its first run (exit unknown), like the --help test flake; 60 reruns clean — add to B-LESLPSGB2TURXZID
- [ ] decision: report reads only git, defaults to last tag..HEAD, outcome from STATE.md add/delete and the Decision: trailer

## Log
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
