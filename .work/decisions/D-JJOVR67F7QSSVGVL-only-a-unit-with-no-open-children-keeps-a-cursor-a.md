---
status: accepted
date: 2026-11-14
read_if:
  - changing what a dev-proc unit's STATE.md holds
  - tempted to keep a Now or Next on a milestone or project
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#cmd-note
  - .agents/skills/dev-proc/scripts/dev-proc.janet#cmd-check
  - .agents/skills/dev-proc/templates/STATE.md
---

# D-JJOVR67F7QSSVGVL Only a unit with no open children keeps a cursor, and it is just Next

## Context
A unit's hand-kept Now and Next, on a parent, repeated what its open children already say and drifted: a milestone's Now named a slice closed four days earlier. On a leaf, Now mostly repeated the last Log line and the Evidence.

## Decision
A unit keeps a cursor, just Next, when it has no open children or is held (awaiting set); Now is dropped. A parent that is not held has none: its present is its open children and its remaining plan lives in Scope or PLAN.md. Existing units are told by warnings, not broken by errors.

## Why
State written twice disagrees sooner or later; the children are the one source for what a parent is doing, and they cannot go stale the way a copy does. One cursor on the unit actually being worked is enough, and Log already holds what just happened. A held parent is the exception because the reason for the hold, which is what a reader needs first, belongs to the parent alone and lasts exactly as long as the hold; once the hold is lifted the leftover Next is stale, so the warning that then appears is the prompt to clean it up.

## Consequences
A parent's STATE.md says less, so a reader finds its status by reading its children. A held unit puts the reason first in Next, as that is where the next reader looks.
