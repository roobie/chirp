---
status: accepted
date: 2026-11-11
read_if:
  - comparing omaps or making deep= see their contents
  - adding compare or hash callbacks to an abstract type
refs:
  - src/omap/omap.h#omap_equal_values
  - src/omap/omap.c#omap_fn_equal
---

# D-JJECECVXGNYXPGEI omap content equality is omap/equal?, not compare and hash callbacks

## Context
omaps compared by identity under `=` and `deep=`. Janet 1.43's `deep=` has no hook for abstract types and falls back to `=`, which uses the type's compare callback, so content equality under `deep=` would need compare and hash callbacks on the omap type.

## Decision
Content equality is the function `omap/equal?`. The omap type has no compare or hash callback, so `=`, `deep=` and hashing stay by identity.

## Why
Janet's marshaller remembers values it has written in a table keyed by `=` and hash. With content compare and hash, two separate omaps with equal entries came back from a marshal as one shared map: changing one changed the other. Tables keyed by omaps would merge them the same way, and since omaps are mutable a key's hash would change under the table.

## Consequences
Code that wants content equality calls `omap/equal?`, not `deep=`. If Janet gains an abstract hook for `deep=` alone, `deep=` can use it without touching compare or hash.
