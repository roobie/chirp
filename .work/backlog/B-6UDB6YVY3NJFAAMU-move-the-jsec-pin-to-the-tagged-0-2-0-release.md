---
created: 2026-11-14
---

# B-6UDB6YVY3NJFAAMU move the jsec pin to the tagged 0.2.0 release

## Why
chirp pins jsec at a commit on its unreleased 0.2.0 branch (9b57288e) because only that branch makes a client `:ca` the sole trust anchor. A development branch can still change under us; a tagged release is the stable point the maintainer stands behind.

## Notes
- The maintainer tagged `v0.2.0-interim1` (mirror 63ce6b8, 2026-11-19, 29 commits past the pin) ahead of the full 0.2.0, partly because windows on 0.2.0 needs work. The interim tag is good enough to pin: it is a point they stand behind, and waiting for the full release would hold back chirp's windows fixes.
- At the bump, pin the tagged commit with its `:tag`, check both jsec patches still apply (or drop the ones upstream took, B-5AUA2Q7IH5DP2ZME), and rerun smoke (`https-ca` covers the `:ca` behaviour).
- The tag carries jsec's own ISC LICENSE (mirror 7656bcc, 2026-11-17; llmII/jsec#2 closed). At the bump, point the jsec notice in tools/build/config.jdn at the pin's LICENSE like every other entry, and drop the reconstructed tools/build/notices/jsec-LICENSE.txt.
- Open jsec tickets (https://code.amlegion.org/jsec/) to check at the bump:
  - c8a4c2ff8c: kqueue surfaces EOF before `SO_ERROR`'s reset reason, so macOS streams may report a plain close where linux reports a reset.
  - 02254cb474: DTLS handshake stalls on BSD/macOS. Matters only if chirp ever uses DTLS.
  - f33e7b7d7e: selective `TLSState` initialisation; a fix there touches the struct the padding patch reasons about.
  - 3654ea6246: multi-OS CI, windows included, on the GitHub mirror. Once it runs, upstream windows breakage shows before it reaches chirp.
