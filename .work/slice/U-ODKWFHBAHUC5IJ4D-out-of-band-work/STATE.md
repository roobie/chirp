---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - git config dev-proc.root <path> makes the CLI use that work dir (any name; absolute, ~ or relative to the repo top)
  - an out-of-band root is never required or named by the commit hooks and trailers, and check warns when its files would be committed
  - find and check still cover the team roots alongside the private one; refs in the private root resolve against the repo
  - tests cover rename, outside-repo and ignored-inside cases; SKILL.md and help describe it
---

# slice/out-of-band-work

## Purpose
Let a person keep their own dev-proc work tree, named and placed as they like (outside the repo or git-ignored inside it), without it leaking into the team's repo, commits or hooks.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

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
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
