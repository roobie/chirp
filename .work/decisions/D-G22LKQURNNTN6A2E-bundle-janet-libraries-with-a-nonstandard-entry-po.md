---
status: accepted
date: 2026-10-24
read_if:
  - adding a pure Janet library to the bundle
refs:
  - tools/build/image.janet#janet-modules
  - tools/build/config.jdn#janet-modules
---

# D-G22LKQURNNTN6A2E Bundle Janet libraries with a nonstandard entry point via :janet-modules data

## Context
The image finds pinned Janet sources by the default `<name>.janet` rule. tomlin's entry point is its root `init.janet`, so `(import tomlin)` did not resolve.

## Decision
Any library whose entry point breaks that rule gets an entry in the config's `:janet-modules` list, and the image turns each entry into a resolution rule.

## Why
The alternatives were a special case for tomlin in the image script, or a copy or rename of upstream files. A special case grows with every new library. A copy or rename is a fork in all but name (D-ZBIADZDYXYPWLX5L). A data entry keeps the image logic generic and the list moddable.

## Consequences
Adding such a library is a config edit, with no code change. Like any config edit, it moves the hashes (B-U6C4GF5ICCTMVVBL).
