---
status: accepted
date: 2026-10-24
read_if:
  - fixing or changing the behaviour of a bundled upstream module
  - adding or removing an overlay
refs:
  - src/chirp/chirp.jdn#overlays
  - src/chirp/overlay-spork-https.janet
  - src/chirp/main.janet#bundled
---

# D-DBGBXVNNTRBBRHMQ chirp corrects bundled modules with an overlay of replacement bindings

## Context
Bundled spork-https behaved against its own docs: clients ignored `:ca`, and requests carried no User-Agent, so GitHub's API refused them. chirp never forks upstream (D-ZBIADZDYXYPWLX5L, D-2SHG5CGZYE2DZCQG), and scripts should keep writing `(import spork-https)`.

## Decision
When a bundled module needs a correction, a chirp-owned module supplies replacement public bindings. chirp.jdn maps the bundled module to that overlay, and they are placed over the upstream env before the image is made.

## Why
A fork would carry a diff on every pin bump and break the "pristine pins" rule. A separate `chirp/https` module would split users between two names, and they would have to change their imports when upstream fixes land. With an overlay, scripts are unaffected, the fix is plain chirp code next to an untouched pin, and it is removed by deleting one chirp.jdn entry. BR chose this on 2026-10-24.

## Consequences
- An overlay must wrap every entry point that reaches the behaviour, because upstream calls its own functions through compiled references. Replacing one binding changes nothing.
- An overlay can only add or replace bindings that upstream already exports. Names private to the overlay never leak.
- Each overlay should be dropped once upstream ships the fix. README states how chirp's copy differs, so users know what to expect.
