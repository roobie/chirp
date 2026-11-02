---
created: 2026-10-24
---

# B-5AUA2Q7IH5DP2ZME Upstream the jsec accept-state patch and audit its other overlapped structs

## Why
chirp carries `tools/build/patches/jsec-iocp-accept-state-padding.patch` (see L-ZDKYOLHCJKJJIE3R) until jsec fixes it, and every patch is a cost at each pin bump. Other jsec users on windows hit the same crash.

## Notes
- The fix is small and upstreamable as it stands. A better long-term fix is for Janet to export `JanetOverlapped` so natives can embed it. That could be raised with Janet too.
- Raise it in the same conversation as the jsec LICENSE file (merged in from B-JVTU4VBH5SAFUE77). jsec declares ISC and its README says "See LICENSE file", but the pin has none, so chirp ships a reconstructed text with no year (tools/build/notices/jsec-LICENSE.txt). BR confirmed ISC on 2026-10-24. With an upstream file, the notices entry could read from the pin like every other one. BR is in touch with llmII anyway (jsys).
- Checked 2026-11-02: upstream master is still the pinned commit (2026-10-04) and has no LICENSE. The README's credits (Janet's tests, cqueues, janet-jdn) cover tests and design, not code chirp compiles, so they need no notice.
- Unaudited: jsec's `TLSState` (jtls/internal.h) and the DTLS state structs (jdtls/server.c, state_machine.c, api/async.c) put `wsa_buf` in the slot Janet writes. It looks harmless for zero-byte probes, but DTLS on windows was not checked.

## Draft issue (for BR to file)
**Add a LICENSE file (and a Windows IOCP accept-state fix)**

The README and project.janet say jsec is ISC and "See LICENSE file", but the repository has no LICENSE. Downstream builds that ship license texts (chirp bundles jsec statically) have to reconstruct the text. Could you add the ISC text with your copyright line and year?

Separately, on Windows, Janet's IOCP loop treats a native's state as a `JanetOverlapped`. That is the `OVERLAPPED` followed by a `uint32_t` byte count, and Janet writes the count on every completion. In `src/jtls/api/server.c` the two accept-state structs put `accept_socket` straight after `WSAOVERLAPPED`, so each completion overwrites it. Reserving a `uint32_t` after the overlapped fixes it (attach `tools/build/patches/jsec-iocp-accept-state-padding.patch`). `TLSState` and the DTLS state structs share the layout and may need the same.
