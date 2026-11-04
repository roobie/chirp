---
phase: execute
parent: U-UETNG3AZPMSATKY2
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - outside a git repo, init, status, new, phase, note, rescope, close, record, find and check work against the nearest work dir found walking up from cwd, or --root; refs resolve against that work dir's parent
  - outside a git repo, trailers, check-msg, check --staged, hooks, report and dig-from-history fail with a message naming git as the need; dig reads closed/ as in a root without history
  - no second configuration path is added for dev-proc.root; without git only the nearest work dir or --root is used
  - tests run the commands in a directory with no git repo; help, SKILL.md and CHANGELOG cover it; the suite passes
---

# task/no-git-repo

## Purpose
dev-proc runs in a directory that is not inside a git repo, with the git-only commands refusing clearly.

## Scope
In: repo-top fallback; root discovery and configured-root without git; clear refusals for git-only commands; tests, help, SKILL.md, CHANGELOG.
Out: an env var or config file for dev-proc.root; discovering every root under a directory without git.

## Context & constraints
- Every command starts with repo-top, which dies outside git; ctx :top is the base for refs, paths and discovery.
- all-roots uses git ls-files; configured-root, ignored? use git.
- Depends on the closed/ archive from task oob-without-history.


## Now
Criteria met; ready to finalize.

## Next
- finalize: record the decision, close, then finalize the slice

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- run: repo-top returns nil outside git; the work dir is the nearest up to / or --root and its parent stands in for top; NEEDS-GIT plus check --staged/--hook refuse; configured-root and all-roots take ctx and give nothing extra without git
- tests: 'outside a git repo the unit and record commands work against the nearest work dir' (init, new, note, rescope, status, record, check, find, supersede, dig, close to closed/, --root), 'the git-only commands say they need git', 'a global dev-proc.root is not used'; all three suites pass
- manual: /tmp dir with no repo, init from a parent and new/status/check from a child, trailers refuses, a .dev-proc.toml above does not crash discovery
- SKILL.md Outside a git repo bullet, help, CHANGELOG

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: outside a git repo dev-proc uses only the nearest work dir or --root, reads no dev-proc.root, and the commit commands refuse

## Log
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
