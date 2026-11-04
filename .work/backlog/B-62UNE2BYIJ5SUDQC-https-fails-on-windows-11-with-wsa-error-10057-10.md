---
created: 2026-11-04
---

# B-62UNE2BYIJ5SUDQC HTTPS fails on windows 11 with WSA error 10057 (#10)

## Why
GitHub #10: on windows 11, chirp 0.7.0 cannot fetch over HTTPS. `chirp --self-update` fails with `Write syscall error: WSA error 10057` (WSAENOTCONN), so windows users cannot self-update and scripts cannot use HTTPS. Smoke checks pass on the windows-2025 CI runner, so CI does not catch it.

## Notes
- Likely cause, read from jsec at the pin (08a92f6, src/jtls/api/connect.c `tls_connect_callback`): on windows `tls/connect` starts a non-blocking `connect()` and its `JANET_ASYNC_EVENT_INIT` falls through to read `SO_ERROR` at once. While the connect is still in progress, SO_ERROR is 0, so jsec starts the TLS handshake on a socket that is not connected yet, and the first write gets WSAENOTCONN. On the CI runner the round trip to GitHub is short, so the connect probably finishes before the check. Janet's own `net/connect` uses ConnectEx on windows (src/core/net.c) and does not have this race.
- Confirm first: reproduce on real windows, or on a runner with added latency, before writing a fix. Check whether a plain `net/connect` to the same host works there.
- Fix options: a chirp patch in tools/build/patches (wait for writability with `select` or WSAPoll, or connect in blocking mode and then switch to non-blocking, the way Janet's fallback does), then upstream it to jsec alongside B-5AUA2Q7IH5DP2ZME. Another option is to open the TCP stream with `net/connect` and upgrade it with jsec's `tls/upgrade`, done in the spork-https overlay.
- jsec upstream has no newer commits than the pin (checked 2026-11-04).
- Related: B-IOPVTTA3XW3OKYXQ, B-7VZIOC4LFIUJMWA2.
