---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-04
success_criteria:
  - The 10057 failure is reproduced on the pristine windows build (Wine with added network latency, or real windows), and the cause is confirmed
  - With the fix, the same reproduction succeeds and the windows smoke checks still pass in CI
  - A check that runs in CI or the local Wine smoke fails on the pristine build and passes on the fixed one
  - 'The fix is offered upstream to jsec (a draft for BR to file is fine) and #10 is answered'
---

# slice/windows-tls-connect

## Purpose
HTTPS from chirp works on real windows: tls/connect must not start the TLS handshake before the TCP connect finishes (GitHub #10).

## Scope
In: jsec's windows TCP connect in tls/connect (a build patch, or a change in the spork-https overlay), a regression check, the upstream draft, the reply on #10.
Out: windows CA roots (B-IOPVTTA3XW3OKYXQ), replacing OpenSSL (B-7VZIOC4LFIUJMWA2), other jsec windows paths (DTLS, server).

## Context & constraints
Builds stay reproducible (two builds, same sha256). chirp does not fork pins; a patch in tools/build/patches is the accepted way to carry a fix (D-MNNDC6PNBUNZXT7O, L-ZDKYOLHCJKJJIE3R). Wine runs the windows build locally via test/smoke/wine; docker is available.

### Origin
Promoted from backlog: B-62UNE2BYIJ5SUDQC HTTPS fails on windows 11 with WSA error 10057 (#10)

### Why
GitHub #10: on windows 11, chirp 0.7.0 cannot fetch over HTTPS. `chirp --self-update` fails with `Write syscall error: WSA error 10057` (WSAENOTCONN), so windows users cannot self-update and scripts cannot use HTTPS. Smoke checks pass on the windows-2025 CI runner, so CI does not catch it.

### Notes
- Likely cause, read from jsec at the pin (08a92f6, src/jtls/api/connect.c `tls_connect_callback`): on windows `tls/connect` starts a non-blocking `connect()` and its `JANET_ASYNC_EVENT_INIT` falls through to read `SO_ERROR` at once. While the connect is still in progress, SO_ERROR is 0, so jsec starts the TLS handshake on a socket that is not connected yet, and the first write gets WSAENOTCONN. On the CI runner the round trip to GitHub is short, so the connect probably finishes before the check. Janet's own `net/connect` uses ConnectEx on windows (src/core/net.c) and does not have this race.
- Confirm first: reproduce on real windows, or on a runner with added latency, before writing a fix. Check whether a plain `net/connect` to the same host works there.
- Fix options: a chirp patch in tools/build/patches (wait for writability with `select` or WSAPoll, or connect in blocking mode and then switch to non-blocking, the way Janet's fallback does), then upstream it to jsec alongside B-5AUA2Q7IH5DP2ZME. Another option is to open the TCP stream with `net/connect` and upgrade it with jsec's `tls/upgrade`, done in the spork-https overlay.
- jsec upstream has no newer commits than the pin (checked 2026-11-04).
- Related: B-IOPVTTA3XW3OKYXQ, B-7VZIOC4LFIUJMWA2.


## Now
Reproducing with the released 0.7.0 chirp.exe under Wine, with netem latency on the container's interface.

## Next
- Confirm the cause (net/connect to the same host works; tls/connect fails only with latency)
- Choose the fix and build it
- Regression check, upstream draft, reply on #10

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-04 initialized
- 2026-11-04 phase initialize → execute
- 2026-11-04 2026-11-04 cause confirmed: pristine 0.7.0 under Wine with 300 ms netem shows connect pending, SO_ERROR 0 read at once, first send before the connect completes; Wine answers that send would-block (so it works), real windows answers WSAENOTCONN
