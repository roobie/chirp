---
created: 2026-11-11
needs: owner
---

# B-VXL2NOPINUAFHAPV Windows chirp exits 127 and loses stdout after cancelling a fiber in a jsec TLS read

## Why
On windows, `ev/cancel` of a fiber blocked in a jsec TLS read, with its zero-byte probe in flight, makes chirp exit 127 after main returns, and stdout is lost. A script that times out a TLS read reports failure and loses its output. Seen 2026-11-04 in slice windows-tls-connect; split out of B-5AUA2Q7IH5DP2ZME, where it sat inside an upstream-filing item.

## Notes
- Suspects: the IOCP state layout already patched for accept (L-ZDKYOLHCJKJJIE3R), here in jsec's `TLSState` (jtls/internal.h), or the probe state freed while the read is still in flight.
- Repro shape: test/smoke/tls-connect-wait.janet with the client cancelled instead of reset. Wine may hide it, as it hid #10; it needs real windows, which means a pushed CI run.
