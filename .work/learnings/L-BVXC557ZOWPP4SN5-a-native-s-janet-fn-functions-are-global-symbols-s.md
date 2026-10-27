---
date: 2026-10-27
read_if:
  - adding a native module to the bundle
  - the cross-link reports a duplicate symbol
refs:
  - src/omap/omap.c
  - src/pcre2/pcre2.c
---

# L-BVXC557ZOWPP4SN5 A native's JANET_FN functions are global symbols, so each needs a prefix

## Observation
`JANET_FN` defines an ordinary non-static C function, and every native is archived into one binary. A name like `cfun_version` therefore collides with the same name in another native: pcre2's `cfun_version` clashed with spork/zip's, and `cfun_compile` with Janet's own. The compile succeeds and only the cross-link fails, with `duplicate symbol`. omap's `omap_fn_*` and pcre2's `chirp_pcre2_fn_*` show the convention.

## Why it matters
A new native whose function names are generic breaks the cross-link, after the slow host build has already passed. Prefix them with the module name from the start. This stops applying if a native is built so that only its entry point is exported.
