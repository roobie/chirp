---
date: 2026-11-04
read_if:
  - testing windows socket code under Wine
  - reproducing a windows-only network race
refs:
  - test/smoke/tls-connect-wait.janet
---

# L-BHOKWWMW54YPXNEM Wine cannot show a windows send-before-connect bug; SO_CONDITIONAL_ACCEPT on real windows can

## Observation
On windows, while a non-blocking connect is in progress, `SO_ERROR` reads 0, and a send on the socket fails with WSAENOTCONN (10057). Wine answers the same send with would-block, so code that sends too early recovers there and works. Wine also ignores `SO_CONDITIONAL_ACCEPT`. On real windows, that option on a listener holds the TCP handshake until the server accepts, which turns a latency race into a failure every time, even on loopback.

## Why it matters
A windows network fix that passes under Wine proves nothing about this class of bug, and loopback or nearby CI servers hide it too, because the connect wins the race. Reproduce it on a real windows runner with conditional accept. Cancelling a fiber while a jsec read is in flight crashed chirp at exit on windows, so a check like this should let its client end on its own.
