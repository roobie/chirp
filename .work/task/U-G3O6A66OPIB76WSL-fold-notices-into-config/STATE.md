---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - The notice sources live in tools/build/config.jdn and tools/build/notices.jdn is gone; nothing in the repo reads or names notices.jdn except history
  - A decision record superseding D-KPP2PSBZKFSROC44 says why one file is enough now; refs that pointed at notices.jdn (e.g. L-A75ZR5MHIETRGB4I) point at config.jdn
  - linux-x64 built before and after the move, each into a fresh out dir, gives the same bin/chirp sha256 and the same NOTICES.txt
---

# task/fold-notices-into-config

## Purpose
TODO: why this unit exists, in one or two sentences.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-XVGIPKGVKMLHDM33 Decide whether notices.jdn stays apart from config.jdn now that config.jdn no longer moves the binary

### Why
D-KPP2PSBZKFSROC44 and the comment atop tools/build/notices.jdn keep the notice sources out of config.jdn because config.jdn's content moved the binary. Task config-jdn-hash-input (U-ILCUNCJK3HY56H64) showed that path was gensym reuse under collector timing, closed by holding the collector off (L-2H7SFLEMCU2MPRZN): unread config.jdn data no longer changes the image. The stated reason is now false either way.

### Notes
- Driver's recommendation: keep notices.jdn separate, and supersede D-KPP2PSBZKFSROC44 with the reason that holds today: the image process should read only what the image uses, so license edits never reach it. Then reword the notices.jdn comment.
- The alternative is folding the list back into config.jdn.
- Owner, 2026-11-11: the split isn't needed any longer; fold the list back into config.jdn.


## Now
Done pending owner review; unit not closed

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- criterion 3: linux-x64 built before (c814157) and after, fresh out dirs; bin/chirp sha256 bbb9439b7612741f99fa1013397b3abb4362b71838593d17f875b64dce898567 and bin/NOTICES.txt 0c154cd340b15d37dd2462d0eb75d83821a91c425e38dc2f375f553fa5164347 identical in both
- criteria 1,2: notices.jdn removed, data under config.jdn :notices; D-MFWFKRO3I2W4SWIR supersedes D-KPP2PSBZKFSROC44; L-A75ZR5MHIETRGB4I refs config.jdn; dev-proc check ok; only history/work docs name notices.jdn

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
