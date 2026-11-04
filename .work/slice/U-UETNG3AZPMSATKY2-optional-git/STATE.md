---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - 'task oob-without-history is delivered: SKILL.md scopes the commit rules to team roots, and a root without git history keeps closed units and superseded records instead of losing them'
  - 'task no-git-repo is delivered: dev-proc''s unit and record commands work outside any git repo, and the git-only commands fail with a clear message'
---

# slice/optional-git

## Purpose
dev-proc's git integration becomes optional: out-of-band work is not held to the commit rules and loses nothing at close, and dev-proc runs in a directory that is not a git repo.

## Scope
In: the two tasks below, in order; task no-git-repo builds on the closed/ archive from oob-without-history.
Out: a second way to configure dev-proc.root (env var or XDG file); a filesystem walk that re-implements .gitignore to find every root without git.

## Context & constraints
- D-6RKLCVKL6N2QK75E made the out-of-band root and kept it out of the hooks, trailers and close's trailer; D-YVHHXLXQHBFKQQ6X added .dev-proc.toml; D-P4UALB3TXI4BV5UM keeps report git-only.
- close and record --supersedes delete files on the premise that git history keeps them; a root with no history loses them.
- dev-proc is a fork of spartan's (D-VZIDK5O2VNATQDCP); keep changes portable.


## Now
task oob-without-history done; task no-git-repo next.

## Next
- task no-git-repo

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- task oob-without-history delivered in c1602c4: closed/ archive, dig fallback, SKILL.md scoping; D-3XCALRBERDES5HTA

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
