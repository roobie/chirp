---
created: 2026-10-24
needs: owner
---

# B-5AUA2Q7IH5DP2ZME Offer jsec its two windows IOCP patches as fossil tickets

## Why
chirp carries `tools/build/patches/jsec-iocp-accept-state-padding.patch` (see L-ZDKYOLHCJKJJIE3R) and `tools/build/patches/jsec-windows-connectex.patch` (D-UIMRRBBCKA7OIVBU) until jsec takes them, and every patch is a cost at each pin bump. Other jsec users on windows hit the same failures.

## Notes
- jsec's primary repo is fossil (https://code.amlegion.org/jsec/); GitHub is a mirror. New asks go there as tickets (D-DZH2PZC2ICEFTDI6), and we follow them through the ticket's feed (L-3HL3LQ37XDKWQ6HI).
- Each patch goes on its ticket as an attachment. The patches are unified diffs with git-style `a/` `b/` prefixes, so they apply with `patch -p1` on a fossil checkout. They are made against the pin, which is fossil check-in d0cc05cb9f (git mirror 9b57288), so each ticket names that check-in.
- No jsec ticket covers either fix (checked 2026-11-15). The pin (fossil d0cc05cb9f, git 9b57288, 2026-10-18) already carries every jsec ticket fixed so far, so both patches are still needed.
- The maintainer said on llmII/jsec#2 (2026-11-15) that windows on the 0.2.0 branch needs work and that they will prioritise what chirp needs, so these are welcome now.
- A better long-term fix for the layout is for Janet to export `JanetOverlapped` so natives can embed it. That could be raised with Janet too.
- The README's credits (Janet's tests, cqueues, janet-jdn) cover tests and design, not code chirp compiles, so they need no notice.
- The audit below makes this layout an unlikely cause of the windows exit-127 after cancelling a TLS read; task U-AUELWJRZ3ADY3DTE re-tests that on 0.2.0.
- Audited, no padding needed: `TLSState` (src/jtls/internal.h:179), `DTLSClientAsyncState` (src/jdtls/internal.h:226) and `DTLSRecvFromState` (src/jdtls/internal.h:251) put a `WSABUF` after the OVERLAPPED, so Janet's count lands on `wsa_buf.len`. Every post rewrites it, and completions take the count from `WSAGetOverlappedResult` or ignore it. That is safe by convention, not by layout, so ticket 1 asks for padding there too. Open ticket f33e7b7d7e (selective TLSState initialisation) touches the same struct.

## Draft ticket 1 (for BR to file)
- Type: Bug
- Subsystem: jtls
- Severity: High
- Priority: High
- Title: Windows IOCP completion overwrites the field after the OVERLAPPED in the accept states

Problem:
On Windows, Janet's IOCP loop treats a native's fiber state as a `JanetOverlapped`: the `OVERLAPPED` followed by a `uint32_t` byte count, which Janet writes on every completion. `janet.h` does not export that layout. `TLSAcceptLoopState` and `TLSAcceptState` put `accept_socket` straight after `WSAOVERLAPPED`, so each completion overwrites it. A zero-byte AcceptEx makes the handle 0, and every TLS server dies on its first connection.

Evidence:
- `src/jtls/api/server.c`: `TLSAcceptLoopState`, `TLSAcceptState`, with `accept_socket` directly after the `WSAOVERLAPPED`
- Symptom: "failed to listen for events: Invalid handle", or a hang, on real Windows and under Wine; Linux never shows it

Observed at check-in: d0cc05cb9f953611fec675e63ed5845993b038a208ccb47d9a626ece5ed7c3fb (branch 0.2.0)

Impact:
`tls/accept` and the accept loop are unusable on Windows.

Suggested fix:
Reserve a `uint32_t` after the overlapped in both accept states (patch attached as a unified diff: `jsec-iocp-accept-state-padding.patch`). `TLSState`, `DTLSClientAsyncState` and `DTLSRecvFromState` share the layout, but there the count lands on `wsa_buf.len`, which every post rewrites and no completion reads. They are safe today only by that convention, so reserving the slot there too would keep a later field from landing on it.

## Draft ticket 2 (for BR to file)
- Type: Bug
- Subsystem: jtls
- Severity: High
- Priority: High
- Title: Windows tls/connect starts the handshake before the TCP connect finishes

Problem:
On Windows, `cfun_connect` starts a non-blocking `WSAConnect`, and `tls_connect_callback` falls through from `JANET_ASYNC_EVENT_INIT` to read `SO_ERROR` straight away. While the connect is still in progress that reads 0, so the handshake's first send fails with `WSAENOTCONN`.

Evidence:
- `src/jtls/api/connect.c`: `cfun_connect`, `tls_connect_callback`
- Error: "Write syscall error: WSA error 10057" (roobie/chirp#10)
- Loopback and servers a millisecond away hide it, because loading the CA file takes longer than the connect. Wine hides it too, because it answers that send with would-block.
- Repro: a listener with `SO_CONDITIONAL_ACCEPT` that accepts after a pause fails every time on real Windows.

Observed at check-in: d0cc05cb9f953611fec675e63ed5845993b038a208ccb47d9a626ece5ed7c3fb (branch 0.2.0)

Impact:
Any `tls/connect` to a server more than a few milliseconds away fails on Windows.

Suggested fix:
Connect with `ConnectEx` and wait for its IOCP completion, as Janet's `net/connect` does (patch attached as a unified diff: `jsec-windows-connectex.patch`). The connect state then starts with the OVERLAPPED and the slot Janet writes, like the accept states in ticket 1.
