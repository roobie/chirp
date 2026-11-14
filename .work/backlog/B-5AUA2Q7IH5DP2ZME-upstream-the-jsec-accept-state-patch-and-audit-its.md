---
created: 2026-10-24
needs: owner
---

# B-5AUA2Q7IH5DP2ZME Upstream the jsec accept-state patch and audit its other overlapped structs

## Why
chirp carries `tools/build/patches/jsec-iocp-accept-state-padding.patch` (see L-ZDKYOLHCJKJJIE3R) until jsec fixes it, and every patch is a cost at each pin bump. Other jsec users on windows hit the same crash.

## Notes
- The fix is small and upstreamable as it stands. A better long-term fix is for Janet to export `JanetOverlapped` so natives can embed it. That could be raised with Janet too.
- The missing jsec LICENSE file is asked for in llmII/jsec#2. Until it lands, chirp ships a reconstructed ISC text with no year (tools/build/notices/jsec-LICENSE.txt); BR confirmed ISC on 2026-10-24. With an upstream file, the notices entry could read from the pin like every other one.
- The README's credits (Janet's tests, cqueues, janet-jdn) cover tests and design, not code chirp compiles, so they need no notice.
- The audit below makes this layout an unlikely cause of the windows exit-127 after cancelling a TLS read; task U-AUELWJRZ3ADY3DTE re-tests that on 0.2.0.
- Audited, no padding needed: `TLSState` (src/jtls/internal.h:179), `DTLSClientAsyncState` (src/jdtls/internal.h:226) and `DTLSRecvFromState` (src/jdtls/internal.h:251) put a `WSABUF` after the OVERLAPPED, so Janet's count lands on `wsa_buf.len`. Every post rewrites it, and completions take the count from `WSAGetOverlappedResult` or ignore it. That is safe by convention, not by layout, so the draft asks for padding there too.

## Draft issue (for BR to file)
**Two Windows IOCP fixes: accept-state layout and tls/connect before the TCP connect finishes**

On Windows, Janet's IOCP loop treats a native's state as a `JanetOverlapped`. That is the `OVERLAPPED` followed by a `uint32_t` byte count, and Janet writes the count on every completion. In `src/jtls/api/server.c`, `TLSAcceptLoopState` and `TLSAcceptState` put `accept_socket` straight after `WSAOVERLAPPED`, so each completion overwrites it. Reserving a `uint32_t` after the overlapped fixes it (attach `tools/build/patches/jsec-iocp-accept-state-padding.patch`). `TLSState` and the DTLS async states share the layout, but there the count lands on `wsa_buf.len`, which every post rewrites and no completion reads. They are safe today, but only by that convention, so reserving the slot there too would keep a later field from landing on it.

Also on Windows, `tls/connect` starts the handshake before the TCP connect has finished. `cfun_connect` in `src/jtls/api/connect.c` starts a non-blocking `WSAConnect`, and `tls_connect_callback` falls through from `JANET_ASYNC_EVENT_INIT` to read `SO_ERROR` straight away. While the connect is still in progress that reads 0, so the handshake's first send fails with `WSAENOTCONN`: "Write syscall error: WSA error 10057" (roobie/chirp#10). Loopback and servers a millisecond away hide it, because loading the CA file takes longer than the connect. Wine hides it as well, because it answers that send with would-block. A listener with `SO_CONDITIONAL_ACCEPT` that accepts after a pause reproduces it every time on real Windows. The fix connects with `ConnectEx` and waits for its IOCP completion, as Janet's `net/connect` does (attach `tools/build/patches/jsec-windows-connectex.patch`).
