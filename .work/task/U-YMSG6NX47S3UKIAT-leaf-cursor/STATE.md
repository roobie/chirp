---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-14
success_criteria:
  - 'the STATE.md template has ## Next and no ## Now; note takes next but not now, which is a usage error naming next and log'
  - note <unit> next on a unit with open children is refused
  - 'check warns on a ## Now section in any unit, and on a non-empty ## Next in a unit with open children'
  - SKILL.md, site docs and CHANGELOG describe the rule; the dev-proc tests pass, new cases included
---

# task/leaf-cursor

## Purpose
A hand-kept cursor on a parent repeats what its open children already say, and it drifts; only the unit being worked keeps one, and Now folds into Next and Log

## Scope
In: the STATE.md template, `note`, `check`, SKILL.md, the site docs, the CHANGELOG and the dev-proc tests.
Out: migrating existing units' STATE.md files (check tells their owners), and `status` surfacing the new warnings (they are check-only, like the other warnings).

## Context & constraints
Decision D-JJOVR67F7QSSVGVL records the rule. A held (awaiting) parent keeps a Next for the reason of the hold. Warnings, not errors, so units written before this stay valid.

## Next
- hand over for review; leave the unit in execute

## Evidence
- dev-proc.test.janet, find.test.janet and frontmatter.test.janet pass (`chirp <file>`), new cases included
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-14 review: a held parent keeps Next (note and check exempt it); SKILL, decision, site, changelog and tests updated
- 2026-11-14 Now dropped, Next only on a unit with no open children: template, note, check, docs, tests; recorded D-JJOVR67F7QSSVGVL
- 2026-11-14 initialized
- 2026-11-14 phase initialize → execute
