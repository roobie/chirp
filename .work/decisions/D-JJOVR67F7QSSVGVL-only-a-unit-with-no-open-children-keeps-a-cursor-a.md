---
status: accepted
date: 2026-11-14
read_if:
  - changing what a dev-proc unit's STATE.md holds
  - tempted to keep a Now or Next on a milestone or project
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#cmd-note
  - .agents/skills/dev-proc/templates/STATE.md
---

# D-JJOVR67F7QSSVGVL Only a unit with no open children keeps a cursor, and it is just Next

## Context
A unit's hand-kept Now and Next, on a parent, repeated what its open children already say and drifted: a milestone's Now named a slice closed four days earlier. On a leaf, Now mostly repeated the last Log line and the Evidence.

## Decision
Only a unit with no open children keeps a cursor, and that cursor is just Next; Now is dropped. A parent's present is its open children, its remaining plan lives in Scope or PLAN.md, and its questions for the owner in the awaiting and needs front matter. `note` refuses Next on a parent and rejects Now, and `check` warns about a Now heading or a filled Next on a parent, so old units migrate by being told rather than by breaking.

## Why
State written twice disagrees sooner or later; the children are the one source for what a parent is doing, and they cannot go stale the way a copy does. One cursor on the unit actually being worked is enough, and Log already holds what just happened. A warning, not an error, keeps units written before this change valid.

## Consequences
A parent's STATE.md says less, so a reader finds its status by reading its children. A held leaf puts the reason first in Next, as that is where the next reader looks.
