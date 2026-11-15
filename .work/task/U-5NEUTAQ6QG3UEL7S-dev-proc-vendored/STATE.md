---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-15
success_criteria:
  - the skill under .agents/skills/dev-proc is a copy written by the owner's vendor sync, and its own design records are no longer kept here
  - AGENTS.md says the copy is vendored and where changes go; tests, leakcheck and dev-proc check pass
  - the installer refuses, with and without --force, to write through a skill dir linked out of its install dir, and the smoke test covers that and the install's own link
---

# task/dev-proc-vendored

## Purpose
dev-proc's canonical home moved to the owner's private tools repo; chirp keeps a one-way vendored copy for public users.

## Scope
In: the vendor sync of .agents/skills/dev-proc, removing the records about dev-proc's own design (they moved upstream with their ids), a decision and an AGENTS.md note, and the installer guard against writing through a link that leaves its install dir (code, smoke test, changelog, decision), because the owner links the live install to the upstream checkout.
Out: the site page, and the installer apart from that guard, because public users install the skill through chirp.

## Context & constraints
The upstream repo is private, so nothing committed here may name its host, its users or any local path. leakcheck enforces that. Records here that mention moved ids keep working by id.


## Next
finalize: harvest is done (decisions D-RFPRKKRRWYW54RHC and D-TKUKHE7T3TSZWWSD recorded); close the unit

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- vendor sync of .agents/skills/dev-proc matches upstream bbab4960f644; leakcheck staged, leakcheck/skillcheck/release tests pass with the built chirp
- guard: chirp built per AGENTS.md (container.sh linux-x64); test/smoke/dev-proc-install.janet passes on that build (refusal with and without --force, project and global, link inside the install dir still installs)
- first build exposed a bug the scratch driver missed (array vs tuple in deep= made every inside link refused); fixed and rebuilt
- second review: the first rule (refuse only links out of the base) missed -g, where checkouts lie under the base; rule is now any link at .agents/skills/dev-proc is refused, with or without --force; smoke test puts the checkout under the install base, covers a dangling link and a linked parent dir (still installs); on a container-rebuilt chirp dev-proc-install is ok
- vendor sync still matches upstream c8681e3a7095 (skills/dev-proc unchanged since bbab4960f644); leakcheck, skillcheck and release tests pass on the rebuilt chirp

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-15 initialized
- 2026-11-15 phase initialize → execute
- 2026-11-15 installer guard implemented with decision D-TKUKHE7T3TSZWWSD; replaces the planned backlog item
- 2026-11-15 guard rewritten to refuse any link at the skill dir; Windows gap recorded as B-GJ36TPGEOECQYDFU
