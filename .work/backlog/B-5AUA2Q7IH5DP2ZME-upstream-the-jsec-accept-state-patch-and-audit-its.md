---
created: 2026-10-24
---

# B-5AUA2Q7IH5DP2ZME Upstream the jsec accept-state patch and audit its other overlapped structs

## Why
chirp carries `tools/build/patches/jsec-iocp-accept-state-padding.patch` (see L-ZDKYOLHCJKJJIE3R) until jsec fixes it, and every patch is a cost at each pin bump. Other jsec users on windows hit the same crash.

## Notes
- The fix is small and upstreamable as it stands. A better long-term fix is for Janet to export `JanetOverlapped` so natives can embed it. That could be raised with Janet too.
- Unaudited: jsec's `TLSState` (jtls/internal.h) and the DTLS state structs (jdtls/server.c, state_machine.c, api/async.c) put `wsa_buf` in the slot Janet writes. It looks harmless for zero-byte probes, but DTLS on windows was not checked.
