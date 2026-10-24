---
created: 2026-10-24
---

# B-5AUA2Q7IH5DP2ZME Upstream the jsec accept-state patch and audit its other overlapped structs

## Why
chirp carries `tools/build/patches/jsec-iocp-accept-state-padding.patch` (see L-ZDKYOLHCJKJJIE3R) until jsec fixes it, and every patch is a cost at each pin bump. Other jsec users on windows hit the same crash.

## Notes
- The fix is small and upstreamable as it stands. A better long-term fix is for Janet to export `JanetOverlapped` so natives can embed it. That could be raised with Janet too.
- Raise it in the same conversation as the jsec LICENSE file (merged in from B-JVTU4VBH5SAFUE77). jsec declares ISC and its README says "See LICENSE file", but the pin has none, so chirp ships a reconstructed text with no year (tools/build/notices/jsec-LICENSE.txt). BR confirmed ISC on 2026-10-24. With an upstream file, the notices entry could read from the pin like every other one. BR is in touch with llmII anyway (jsys).
- Unaudited: jsec's `TLSState` (jtls/internal.h) and the DTLS state structs (jdtls/server.c, state_machine.c, api/async.c) put `wsa_buf` in the slot Janet writes. It looks harmless for zero-byte probes, but DTLS on windows was not checked.
