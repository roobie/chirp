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
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

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
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
