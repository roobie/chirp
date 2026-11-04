---
status: accepted
date: 2026-11-04
read_if:
  - changing what dev-proc close or record --supersedes removes
  - running dev-proc in a work dir outside git history
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#history-top
  - .agents/skills/dev-proc/scripts/dev-proc.janet#dig-closed
---

# D-3XCALRBERDES5HTA A work dir without git history keeps closed units and superseded records in closed/

## Context
close and record --supersedes delete files because git history keeps the last version, and dig reads it back. An out-of-band work dir outside any repo, or git-ignored in the team's, has no history, so closing there lost the unit for good.

## Decision
A work dir has history when it sits in a git repo and is not ignored there. Without history, close moves the unit dir and record --supersedes moves the old decision to the work dir's `closed/`, and dig reads them from there. With history, nothing changes.

## Why
Keeping the files is the only option that loses nothing and still lets `close` empty the active tree. Refusing to close would leave finished units in status forever. Keeping closed units in place under a closed phase would make every reader filter them out. `closed/` is outside the type and record dirs that load-root reads, so status, find and check skip it with no extra code. Deciding from where the work dir sits, not from a flag, follows D-6RKLCVKL6N2QK75E.

## Consequences
`closed/` grows with every unit closed; pruning it is up to the person. Refs in archived files are not checked and may go stale. A work dir in git whose files were never committed still loses them at close; the commit rules cover that.
