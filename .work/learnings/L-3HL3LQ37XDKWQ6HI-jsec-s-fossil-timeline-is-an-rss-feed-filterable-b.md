---
date: 2026-11-15
read_if:
  - watching jsec or spork-https upstream for replies, tickets, check-ins or tags
  - matching a jsec mirror commit to a fossil check-in
refs:
  - pins.jdn#jsec
---

# L-3HL3LQ37XDKWQ6HI jsec's fossil timeline is an RSS feed filterable by ticket, branch, tag and type

## Observation
code.amlegion.org/jsec/timeline.rss serves the timeline as RSS to anyone without logging in. `y=` picks the event type: `t` tickets, `ci` check-ins, `w` wiki, `g` tag and branch edits. The server accepts `g` even though `fossil rss --help` doesn't list it, and `y=all` leaves tag edits out. `tkt=<hash>` narrows the feed to one ticket and shows each status change and comment, `tag=<name>` to a branch (`0.2.0`) or a tag, and `n=` sets how many items you get. The other llmII repos serve the same feed under their own path.

Tickets have no other notification without an account, so these feeds are how we watch: `tkt=` for each ticket we file, `y=t` for new tickets, `y=ci&tag=0.2.0` for the branch we pin, and `y=g` for a new tag such as 0.2.0-interim. `tag=` only works once the tag's name is known.

`fossil clone https://code.amlegion.org/jsec` works anonymously and copies the tickets as well. After that, `fossil rss -R`, `fossil timeline -t t` and `fossil ticket show` work offline.

The GitHub mirror's git hashes differ from fossil's check-in hashes. Match a commit by its timestamp and comment: chirp's pin 9b57288 is fossil check-in d0cc05cb9f, "Merge ticket-43b3122615 into 0.2.0 series", 2026-10-18 17:32:52.

## Why it matters
Upstream replies and releases appear only on fossil, so whatever doesn't read these feeds misses them. Quoting a git hash on fossil, or a fossil hash in pins.jdn, points at nothing.
