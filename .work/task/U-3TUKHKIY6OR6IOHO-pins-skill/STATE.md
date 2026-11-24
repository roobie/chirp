---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - .agents/skills/chirp-pins/SKILL.md holds both procedures, each step naming its guard or marked as done by hand, with the .claude/skills link; skillcheck passes.
  - A reader can bump a pin from the skill alone, which wave D tests.
---

# task/pins-skill

## Purpose
Moving a pin and adding a bundled component are written procedures that name the guard behind each step, so neither depends on memory (findings 1, 2, 3).

## Scope
In: the skill file, its `.claude/skills` link, a pointer in the README.
Out: proving it on a real bump (slice pin-bump-proof, wave D); the `:chirp` pin, which the release skill moves.

## Context & constraints
Written last in its wave so that it names guards that exist: patches, mirrors, notices and version defines stop the build (waves A and B), repo C compiles with warnings as errors, `watch.janet` lists what is newer. What no guard holds is marked by hand: the tag and commit agreeing, the license text changing, help text that describes changed behaviour, a smoke check existing for a new module.


## Next
Merge with wave C. The second criterion is judged by wave D; finalize after the wave's CI, leaving that proof to pin-bump-proof.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- The skill has 'Moving a pin' (10 steps) and 'Adding a bundled component' (9 steps); each build message it quotes is one build.janet raises; skillcheck passes with the link in place.
- ci run 45422435654 (98cd9d6): the checks job's skillcheck passes with the new skill and link. Whether a reader can bump from it alone is left to slice pin-bump-proof, which fixes the skill where it was wrong.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [x] backlog (B-26BRL3WAR4BVJUZS): the build does not check that a pin's :tag and :commit name the same upstream commit; the skill covers it by hand

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
