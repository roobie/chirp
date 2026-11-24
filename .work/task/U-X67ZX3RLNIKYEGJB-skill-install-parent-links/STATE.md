---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - A link at any directory between the install base and the skill dir is refused, forced or not, with nothing written; a unit test and a smoke case hold it.
  - The smoke case passes on linux and macOS; windows keeps its known exception (B-GJ36TPGEOECQYDFU).
  - The decision D-TKUKHE7T3TSZWWSD is superseded or extended, the changelog has an entry, and the issue is on the next release's GitHub milestone.
---

# task/skill-install-parent-links

## Purpose
A skill install never writes through a link, at the skill dir or above it, so a forced install cannot overwrite a checkout reached through a linked .agents (issue 20).

## Scope
In: the check in `src/chirp/skills.janet` for the canonical copy and for `--copy`; unit and smoke cases; the decision; the changelog; the issue's milestone.
Out: Windows, where links are not seen (B-GJ36TPGEOECQYDFU); a link above the install base; cutting the release the issue asks for.

## Context & constraints
D-TKUKHE7T3TSZWWSD allowed a linked parent on purpose and the smoke check asserted it; that case is turned around here. This repo's own `.claude/skills` may be a link to `.agents/skills`, which only ever receives a link and must keep working.


## Next
CI on the wave branch: smoke on linux and macOS. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- skills.test.janet: a linked .agents and a linked .agents/skills are each refused, forced or not, with the store's file unchanged and no .claude made; --copy refuses a linked .claude; .claude/skills linked to .agents/skills still installs. linux-x64 built locally passes all smoke checks, with dev-proc-install's parent-link case turned from 'works' to 'refused, nothing written'.
- Decision D-Z6BXK3LRIQKGMJBN extends D-TKUKHE7T3TSZWWSD; the changelog has the entry under Unreleased; GitHub milestone 0.13.2 was created and holds issue 20 (retitle it if the next release gets another number).
- ci run 45422435654 (98cd9d6): dev-proc-install passes on linux-x64, linux-arm64 and macos-arm64 with the parent-link case, and on windows, where the case does not run; the checks job passes skills.test.janet on the pinned 0.13.1.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
