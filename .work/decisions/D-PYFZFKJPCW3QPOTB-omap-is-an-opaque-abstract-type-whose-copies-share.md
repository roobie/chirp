---
status: accepted
date: 2026-10-25
read_if:
  - changing the omap type or adding a native that builds one
  - wondering why omap is not a table
refs:
  - src/omap/omap.h#omap_type
---

# D-PYFZFKJPCW3QPOTB omap is an opaque abstract type whose copies share one registered type

## Context
Scripts that rewrite JSON or YAML a person maintains lose the author's key order, because Janet tables have none. Janet has no ordered table (janet-lang/janet#925 was closed), and no Janet package offers one. Several natives (omap, yaml, the ordered JSON decoder) must build and read the same map.

## Decision
chirp owns an insertion-ordered map as a Janet abstract type. Each native compiles its own copy of the code, and all copies use the one type registered under the name "omap".

## Why
BR weighed four shapes for tech debt. Hiding the order in a table's prototype loses it silently on any copy or merge. Arrays of pairs push lookup helpers into every script. Ordering every decode by default breaks the promise that the overlays leave scripts unaffected. An opaque type is the one where a consumer that does not know it fails loudly instead of dropping the order. Sharing the type by name means no native depends on another being linked or loaded first.

## Consequences
`table?` and `dictionary?` are false for an omap, so code that only accepts tables needs to learn the type. Each encoder chirp bundles has to handle it explicitly. Changing the struct layout means changing every native that includes the header in the same build.
