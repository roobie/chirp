---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - The jsec pin names the tag v0.2.0-interim1 and its commit, and the bump is on main with CI green on all targets.
  - Evidence lists every place the chirp-pins skill was wrong or silent during the bump, and each is fixed in the skill in this slice (none is an acceptable count).
  - No upstream project was contacted.
---

# slice/pin-bump-proof

## Purpose
One real pin bump, jsec to v0.2.0-interim1, done from the chirp-pins skill by an agent that did not write it, proves the procedure and corrects it where it was wrong or silent.

## Scope
In: the jsec pin and whatever the build, the skill and this unit's notes below ask for at the bump; corrections to `.agents/skills/chirp-pins/SKILL.md`.
Out: any other pin; contacting upstream in any form (no ticket, issue, pull request, patch offer, mail or post; reading is allowed); cutting a release; merging to main, which the session that started this slice does after reading the result. If jsec cannot go green within the slice, the pin goes back and a quiet tagged pin (md4c or lexbor) proves the procedure instead, should one have a newer tag.

## Context & constraints
The procedure is `.agents/skills/chirp-pins/SKILL.md`, written in wave C of milestone U-HM3MZPOZSVLCXGNP by another agent. The point of this slice is to follow it as written: where it is wrong, unclear or silent, write that down under Log as it happens and fix the skill, instead of working around it silently. Work happens on branch `pin-bump-proof`; pushing the branch runs CI.

### Origin
Promoted from backlog: B-6UDB6YVY3NJFAAMU move the jsec pin to the tagged 0.2.0 release

### Why
chirp pins jsec at a commit on its unreleased 0.2.0 branch (9b57288e) because only that branch makes a client `:ca` the sole trust anchor. A development branch can still change under us; a tagged release is the stable point the maintainer stands behind.

### Notes
- The maintainer tagged `v0.2.0-interim1` (mirror 63ce6b8, 2026-11-19, 29 commits past the pin) ahead of the full 0.2.0, partly because windows on 0.2.0 needs work. The interim tag is good enough to pin: it is a point they stand behind, and waiting for the full release would hold back chirp's windows fixes.
- At the bump, pin the tagged commit with its `:tag`, check both jsec patches still apply (or drop the ones upstream took, B-5AUA2Q7IH5DP2ZME), and rerun smoke (`https-ca` covers the `:ca` behaviour).
- The tag carries jsec's own ISC LICENSE (mirror 7656bcc, 2026-11-17; llmII/jsec#2 closed). At the bump, point the jsec notice in tools/build/config.jdn at the pin's LICENSE like every other entry, and drop the reconstructed tools/build/notices/jsec-LICENSE.txt.
- Open jsec tickets (https://code.amlegion.org/jsec/) to check at the bump:
  - c8a4c2ff8c: kqueue surfaces EOF before `SO_ERROR`'s reset reason, so macOS streams may report a plain close where linux reports a reset.
  - 02254cb474: DTLS handshake stalls on BSD/macOS. Matters only if chirp ever uses DTLS.
  - f33e7b7d7e: selective `TLSState` initialisation; a fix there touches the struct the padding patch reasons about.
  - 3654ea6246: multi-OS CI, windows included, on the GitHub mirror. Once it runs, upstream windows breakage shows before it reaches chirp.


## Next
<!-- The cursor of the unit being worked: what is about to happen, and for a held unit the reason first.
     Rewrite it freely. A unit with open children keeps none: its present is its children. -->

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

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
