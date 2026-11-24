---
phase: execute
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - chirp tools/pins/watch.janet prints, for every pin, the newer tags or that it is current, and the feeds' recent items; it exits 0 and writes nothing.
  - The tag ordering has a test.
  - The chirp-release preflight has a line for it.
---

# task/upstream-watch

## Purpose
One command shows what upstream has published since the pins were set, so a bump starts from facts and nothing upstream goes unnoticed (finding 2).

## Scope
In: `tools/pins/watch.janet`, its data `tools/pins/watch.jdn` (branches of untagged pins, feeds), a test of the tag ordering and the feed parsing, the release preflight line, a README paragraph.
Out: remembering the last check (it would be state on one machine; `--days N` gives the window instead, default 30); a scheduled run (not wanted, BR 2026-11-24); acting on what it prints.

## Context & constraints
It reads with `git ls-remote` and HTTPS GET only and contacts nobody. The jsec pin follows branch `0.2.0` of the GitHub mirror, not the default branch, so branches are data. zig has no git pin; its releases are the keys of ziglang.org's download index. The test runs on the pinned released chirp and touches no network.

### Origin
Promoted from backlog: B-DE4OCJCKANMSZ75T Watch llmII's fossil feeds for replies, tickets, check-ins and tags

### Why
Replies to our jsec tickets, new tickets, 0.2.0 check-ins and new tags appear only on fossil (D-DZH2PZC2ICEFTDI6), and nobody is notified of them. Without a watcher we would notice them only when someone happens to look.

### Notes
- The feeds are listed in L-3HL3LQ37XDKWQ6HI: `tkt=` per filed ticket, `y=t`, `y=ci&tag=0.2.0` and `y=g` for each llmII repo we pin (jsec, spork-https).
- Shape: a chirp/janet script under tools/ (D-ANH2OMRLGDIIVVZY) that reads the list of feeds from a data file, fetches each one, and prints the items newer than the last check. Only the script is logic; the feeds are data. Filing a ticket adds its `tkt=` feed to the data file in the same commit.
- The last check's time is per-machine state, so it stays out of the repo (for example under XDG state) and is never committed. Running it with no state lists everything since a given date.
- Run it before a pin bump (B-6UDB6YVY3NJFAAMU), from a scheduled routine, or both.


## Next
CI checks job must pass the new test on the pinned chirp. Then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- chirp tools/pins/watch.janet (2026-11-24, 13 s, exit 0, git status unchanged): janet v1.43.0 newer v1.43.1; libyaml newer 0.2.6-rc.1 0.2.6 0.2.7; openssl newer 4.0.0 … 4.1.0-beta2; zig newer 0.16.0 0.17.0 0.17.1; lexbor, md4c, pcre2, spork-https, sqlite3, tomlin current; jsec's branch 0.2.0 and spork's default branch moved; the three image and chirp pins say why they are not watched; eight feeds, the jsec ones showing the v0.2.0-interim1 tag of 2026-11-19.
- watch.test.janet holds the ordering (numbers as numbers, the pin's spelling only, suffixed tags, pcre2-10.49 not read as version 2) and the feed parsing; the first run caught that last case as a real bug. Preflight step 8 of the chirp-release skill names the command.

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
