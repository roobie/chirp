---
created: 2026-10-24
---

# B-JVTU4VBH5SAFUE77 Ask jsec upstream to add the LICENSE file its README points to

## Why
jsec declares ISC in project.janet and its README says "See LICENSE file", but the pinned checkout has none. So chirp ships a reconstructed text with no year (tools/build/notices/jsec-LICENSE.txt). An upstream file would make the notice authoritative, and the notices entry could then read from the pin like every other one.

## Notes
- BR is in contact with llmII anyway (HANDOFF.md, jsys). Fold this into that conversation, together with the windows IOCP patch (B-5AUA2Q7IH5DP2ZME).
