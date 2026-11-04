---
status: accepted
date: 2026-11-04
read_if:
  - changing how chirp connects TLS clients on windows
  - bumping the jsec pin
  - a windows HTTPS request fails with a WSA error
refs:
  - tools/build/patches/jsec-windows-connectex.patch
  - tools/build/build.janet
  - test/smoke/tls-connect-wait.janet
---

# D-UIMRRBBCKA7OIVBU Fix windows tls/connect with a jsec ConnectEx patch, not in the spork-https overlay

## Context
On windows, jsec's `tls/connect` started the handshake before its non-blocking TCP connect finished. Any server more than a few milliseconds away made the first send fail with WSAENOTCONN (#10), and that broke `chirp --self-update` as well as scripts. jsec upstream had no newer commit than the pin.

## Decision
chirp carries a build patch to jsec that connects with ConnectEx and waits for its IOCP completion, as Janet's own `net/connect` does. It is offered upstream (B-5AUA2Q7IH5DP2ZME).

## Why
- The alternative was the spork-https overlay: open the TCP stream with `net/connect`, then upgrade it with `tls/upgrade`. That fixes only callers that use the overlay. The update module sees upstream spork-https, not the overlay (L-OFSXUYK57K7GM4JD), and scripts that call `jsec/tls` directly would stay broken.
- A blocking connect, which is Janet's own fallback, would stall the event loop for a whole round trip, or until the connect timed out.
- ConnectEx is the primitive that the IOCP loop already supports, so the patch is small and windows-only, and upstream can take it as it is.

## Consequences
- A second jsec patch has to apply at every pin bump until upstream takes it; the build fails loudly when it stops applying.
- The connect state now starts with the OVERLAPPED and the slot Janet writes (L-ZDKYOLHCJKJJIE3R), the same as the accept states.
- tls-connect-wait guards the behaviour on the windows CI runner only; Wine skips it.
