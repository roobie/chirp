---
status: accepted
date: 2026-11-15
read_if:
  - filing or drafting a ticket, patch or question for jsec, spork-https, janet-assay or jsys
  - bumping the jsec or spork-https pin
  - citing a jsec or spork-https commit
refs:
  - pins.jdn#jsec
---

# D-DZH2PZC2ICEFTDI6 Work with llmII's projects through their fossil repos; pins stay on the GitHub mirror

## Context
jsec, spork-https, janet-assay and jsys are llmII's projects. Each has a fossil repo at code.amlegion.org and a git mirror on GitHub. chirp pins jsec and spork-https from the mirror.

## Decision
Tickets, patches and questions for these projects go to their fossil repos. A patch is a plain unified diff attached to a ticket, naming the fossil check-in it applies to. A forum or chat thread needs an account the maintainer grants. llmII/jsec#2 (the LICENSE request) stays on GitHub by agreement. Pins and the README's links stay on the GitHub mirror.

## Why
- The maintainer develops in fossil and treats GitHub as a mirror they sync by hand (llmII/jsec#2, 2026-11-15). Work filed on GitHub makes them carry it across.
- Fossil has no pull requests, so a ticket with an attached diff is the native way to offer a change.
- The mirror is maintained and already holds every pinned commit. Fetching from fossil would add fossil to the build container for no gain.

## Consequences
- A commit has two hashes: the mirror's git hash in pins.jdn and the fossil check-in hash in tickets. Say which one you mean (L-3HL3LQ37XDKWQ6HI explains how to match them).
- Upstream replies arrive on fossil, not as GitHub notifications, so we watch the fossil feeds.
