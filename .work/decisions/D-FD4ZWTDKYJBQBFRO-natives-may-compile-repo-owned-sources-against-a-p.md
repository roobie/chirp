---
status: accepted
date: 2026-10-25
read_if:
  - adding a native whose binding lives in this repo
refs:
  - tools/build/build.janet#native-sources
  - tools/build/natives.jdn
---

# D-FD4ZWTDKYJBQBFRO Natives may compile repo-owned sources against a pinned library

## Context
Until yaml, every native's sources came from its pinned checkout. A binding that chirp writes itself has no upstream checkout to live in, yet it must build against one.

## Decision
A native may list sources that live in this repo beside the pinned library's sources, and extra include directories in the pin.

## Why
Copying the binding into the pin's checkout at build time would hide chirp's code inside a third-party tree and make the pin no longer a clean upstream copy. Vendoring libyaml into the repo would lose the pin's commit as proof of provenance. Keeping the binding in the repo and the library in the pin keeps each owned by the right party.

## Consequences
Repo-owned sources are compiled from an absolute repo path, so the build maps that path away to keep binaries identical across checkouts. Any further chirp-owned binding (for example over a C regex or XML library) follows the same shape.
