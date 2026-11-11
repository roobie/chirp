---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - The path by which a config.jdn edit the image never reads changes the linux-x64 binary is named, with a reproduction (before/after hashes and the differing bytes or image entries)
  - Either a fix lands so such an edit leaves the binary's sha256 unchanged (shown by two builds), or the cause is recorded as a learning and the fix is gated on the owner with the evidence
---

# task/config-jdn-hash-input

## Purpose
An input to the image that nobody can explain is a reproducibility risk. This unit finds how unread config.jdn content reached the binary and whether that path is still open.

## Scope
In: tracing the path, reproducing it, and fixing it or gating the fix on the owner.
Out: other inputs to the image process, and moving notices back into config.jdn (an owner decision).

## Context & constraints
The image is written by a fresh janet running tools/build/image.janet, and that process parses config.jdn. CI builds every target twice and requires both sha256 hashes to match (D-Q23RA2EVVN5LYCX7).

### Origin
Promoted from backlog: B-U6C4GF5ICCTMVVBL Find how config.jdn content reaches the image

### Why
Adding a key to tools/build/config.jdn that the image never reads moved the linux-x64 hash (484a2667… → 9714e68b…). Builds still agree with each other, so reproducibility holds, but an unexplained input to the image is the kind of thing that later breaks it. Until it is understood, any config.jdn edit is a hash change, and releases from before and after it can't be compared.

### Notes
- tools/build/image.janet parses config.jdn in the image-building process. A likely cause is that the parsed data's allocation shifts the hash order of something that does get marshalled. L-ZI52YKRRPPUHTQEI shows the same kind of effect through the gensym counter, but parsing data calls no gensym, so that alone does not explain it.
- Repro: add an unused key to config.jdn, build linux-x64, and compare.


## Now
Cause found and shown to be closed by 7544abd's gcsetinterval. No code change is needed. Waiting for the owner to decide on D-KPP2PSBZKFSROC44 and the notices.jdn comment.

## Next
Owner: keep notices.jdn separate (then reword its why) or fold it back into config.jdn. Then finalize: record the learning and close B-U6C4GF5ICCTMVVBL's line of work.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Path: the parsed config's allocation moved when janet's collector ran during the image build, and gensym reuses the names of freed gensyms (L-2H7SFLEMCU2MPRZN), so the gensym names in the marshalled image shifted. The edit was observed in f070af2 (2026-10-24 15:58); 7544abd (2026-10-25 01:51) put image.janet's gcsetinterval in place, which closed this path before the backlog item was looked at.
- Repro, collector on (image.janet with its gcsetinterval line removed, image step rerun alone in the pinned container against one finished out dir): an unread key of N short strings gives image hashes N=0 8b1792d8, 1000 8b1792d8, 5000 c24de769, 20000 1f319d0b, 50000 8041a680. Diffing the decoded image blobs, 0 vs 5000 differ in 454 bytes and 0 vs 50000 in 634, all inside _0000xx gensym names: with those names masked the blobs are identical, and the length (1866934) does not change.
- Collector off (main today): the same sweep (N=0, 5000, 20000, 50000, 200000) gives one image hash, dc8e5841, for every N, and adding the 2026-10-24 notices list to config.jdn as an unread :notices key leaves it unchanged too. The image-only rerun gives byte-identical C to the full build.
- Real build, linux-x64 via container.sh: main at 7973365 gives bin/chirp bbb9439b…98567 (image C dc8e5841…). With the notices list added to config.jdn and a rebuild in the same out dir, bin/chirp is again bbb9439b…98567. An earlier attempt to use a second out dir failed because the shared /tmp tmpfs filled up (ENOSPC). It was not a hash difference.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] learning: extend L-2H7SFLEMCU2MPRZN, or record a new learning, saying that unread build data parsed in the image process (config.jdn) was one of these GC-timing inputs and that holding the collector off covers it
- [ ] decision: D-KPP2PSBZKFSROC44's reason (config.jdn content moves the binary) no longer holds. The owner decides whether notices stay in notices.jdn for separation alone, and the comment at the top of tools/build/notices.jdn needs to say so

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
- 2026-11-11 cause traced to GC-timed gensym reuse, already fixed by 7544abd; confirmed on a real linux-x64 build
