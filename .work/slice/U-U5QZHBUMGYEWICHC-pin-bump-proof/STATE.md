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
Owner review/integration only: branch all-target CI is green. Leave this slice in execute; main integration criterion remains for the owner. No merge, tag or release performed.

## Evidence
- `git ls-remote` resolves `v0.2.0-interim1` to mirror commit `63ce6b85c88f0448cd9be415fcb0f7ad538d432b`. Read old-to-tag log, diff stat, NEWS and license: Windows IOCP/ConnectEx, BSD/macOS reset parity, DTLS MTU, security fixes and ISC LICENSE added.
- Build patch guard caught retired accept patch. Source inspection confirms both fixes are upstream; removed both patches and settled B-5AUA2Q7IH5DP2ZME without filing anything. Repaired durable refs; `dev-proc check` passes.
- New upstream LICENSE is the same ISC grant/disclaimer as the reconstructed notice, with copyright year added. Switched notice to pin LICENSE and removed the reconstruction. Windows compatibility flags remain justified by source.
- Local `sh tools/build/container.sh linux-x64 out/bump` completed; `out/bump/bin/chirp test/smoke/run.janet` passed all checks, including exclusive `https-ca` trust. Windows-only connect race check skipped locally as designed.
- `chirp tools/test.janet src tools`: all 12 test files passed.
- Source review: DTLS `mtu.c` is picked up by directory sources; API diff adds optional MTU and does not change documented chirp trust behavior. TLSState now reserves the IOCP slot too. Removed the settled bump's f33e7b7d7e feed and obsolete untagged jsec branch hint. Kept thread-local feed/flag: upstream still uses `__declspec(thread)` in compat.h.
- B-OM3ZCJZZN7XPUD3D (Windows cancellation exit/stdout regression) remains a separate, unproved backlog item; no cancellation regression test added by this pin bump.
- CI run `45435023130`, attempt 1: all ten builds, five-target reproducibility comparison, checks, WASM and Linux/Windows smoke passed. macOS smoke job `138598492029` was cancelled before any steps, with no runner or logs. Check-run annotations report hosted macOS ARM capacity / job not acquired. Retrying failed job, not changing pin code.
- CI run `45435023130`, attempt 2, **success**, head `62d5e39fa99b14dbbc18c7d6104d172e9f9bfecc`: all ten builds, reproducibility comparison on all five targets, four native smoke jobs, WASM smoke/try page, checks. macOS acquired a runner on retry and passed all smoke checks. Windows log explicitly reports `ok tls-connect-wait: the handshake started after the TCP connect`; macOS and Windows both report exclusive `https-ca` success.
- No upstream project contacted: only read-only watch/fetch/ls-remote/source inspection. Git writes/pushes and CI retries were confined to chirp's `pin-bump-proof`; no main push/merge, tags or releases.
- `dev-proc check` passes; branch remains execute for owner handoff.
- Five skill corrections total, enumerated in Log and applied in `.agents/skills/chirp-pins/SKILL.md`.
- Scope remains branch-only: the main integration criterion is for the owner after handoff; no merge, tag or release in this run.

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
- 2026-11-24 skill correction (Moving step 2): build checkouts are shallow; `git diff 9b57288 HEAD` in the new checkout fails with bad revision. Documented explicitly fetching both comparison commits and using endpoint diffs for a tag merged from another branch.
- 2026-11-24 skill correction (Moving step 4, patch retirement): deleting patches leaves durable refs dangling, and both jsec patches share one backlog item. Added ref repair/`$DP check` and shared-item settlement instructions.
- 2026-11-24 skill correction (Moving step 5): an existing reconstructed notice passes the guard even when upstream adds LICENSE; documented migration of root/path, local file and comments. Also quoted `LICENSE*` to avoid shell expansion hiding deleted license files.
- 2026-11-24 skill correction (Moving step 10): unconditional close conflicts with branch-only proof/handoff. Require evidence first and close only when criteria and owner instructions permit.
- 2026-11-24 run 45435023130 attempt 2 green on all targets after retrying the unacquired macOS job. No source fix needed after CI; Windows ConnectEx regression and exclusive CA smoke pass. Evidence complete; leaving execute and main integration to owner.
- 2026-11-24 skill correction (Moving step 9): silent on a cancelled CI job without logs or steps. Run 45435023130 had no macOS runner due to hosted ARM capacity. Added watch commands, check-run annotations diagnosis and failed-job infrastructure retry guidance.
- 2026-11-24 local linux build, smoke and all 12 tool/source test files passed; ready for all-target branch CI.
- 2026-11-24 first linux build stopped at accept-padding patch as expected. Inspected new accept states (both reserve `iocp_bytes`) and ConnectEx callback (waits for IOCP completion and updates connect context): upstream implements both fixes, so retire both patches. Existing `__declspec(thread)` and clock_gettime remain: keep windows flags. No upstream contact.
