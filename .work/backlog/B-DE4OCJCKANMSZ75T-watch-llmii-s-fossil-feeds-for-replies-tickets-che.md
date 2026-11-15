---
created: 2026-11-15
---

# B-DE4OCJCKANMSZ75T Watch llmII's fossil feeds for replies, tickets, check-ins and tags

## Why
Replies to our jsec tickets, new tickets, 0.2.0 check-ins and new tags appear only on fossil (D-DZH2PZC2ICEFTDI6), and nobody is notified of them. Without a watcher we would notice them only when someone happens to look.

## Notes
- The feeds are listed in L-3HL3LQ37XDKWQ6HI: `tkt=` per filed ticket, `y=t`, `y=ci&tag=0.2.0` and `y=g` for each llmII repo we pin (jsec, spork-https).
- Shape: a chirp/janet script under tools/ (D-ANH2OMRLGDIIVVZY) that reads the list of feeds from a data file, fetches each one, and prints the items newer than the last check. Only the script is logic; the feeds are data. Filing a ticket adds its `tkt=` feed to the data file in the same commit.
- The last check's time is per-machine state, so it stays out of the repo (for example under XDG state) and is never committed. Running it with no state lists everything since a given date.
- Run it before a pin bump (B-6UDB6YVY3NJFAAMU), from a scheduled routine, or both.
