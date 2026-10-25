---
status: accepted
date: 2026-10-25
read_if:
  - changing json/encode in the overlay
refs:
  - src/chirp/overlay-spork-json.janet#encode
---

# D-YMKKGLNX3IGQPAGJ json/encode tries spork's encoder before looking for an omap

## Context
The overlay replaces json/encode for every script, and most values hold no omap. Looking through a value for an omap before encoding would make every plain encode pay for a full walk.

## Decision
json/encode runs spork's encoder first. Only when spork's encoder fails, and the value holds an omap, does the overlay encode it in Janet.

## Why
spork's encoder rejects an omap as an unsupported type, so a failure is the signal that an omap may be present. Plain values then run exactly spork's code at spork's speed, which is the overlay's promise. Values that hold an omap pay for one failed attempt, which is acceptable because they are the rare case.

## Consequences
A failed attempt may already have written into a buffer the caller passed, so the overlay has to cut that buffer back before encoding again. If spork's encoder ever accepts abstract types, this signal stops working and the overlay has to be revisited.
