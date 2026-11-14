---
created: 2026-11-14
---

# B-6UDB6YVY3NJFAAMU move the jsec pin to the tagged 0.2.0 release

## Why
chirp pins jsec at a commit on its unreleased 0.2.0 branch (9b57288e) because only that branch makes a client `:ca` the sole trust anchor. A development branch can still change under us; a tagged release is the stable point the maintainer stands behind.

## Notes
Once llmII/jsec tags 0.2.0, pin that commit with its `:tag`, check both jsec patches still apply, and rerun smoke (`https-ca` covers the `:ca` behaviour).
