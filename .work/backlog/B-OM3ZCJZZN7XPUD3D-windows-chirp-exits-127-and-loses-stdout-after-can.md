---
created: 2026-11-24
---

# B-OM3ZCJZZN7XPUD3D Windows chirp exits 127 and loses stdout after cancelling a fiber in a jsec TLS read

## Why
On windows, `ev/cancel` of a fiber blocked in a jsec TLS read, with its zero-byte probe in flight, makes chirp exit 127 after main returns, and stdout is lost. A script that times out a TLS read reports failure and loses its output. Seen 2026-11-04 in slice windows-tls-connect; split out of B-5AUA2Q7IH5DP2ZME, where it sat inside an upstream-filing item.

## Notes
- Suspects: the IOCP state layout already patched for accept (L-ZDKYOLHCJKJJIE3R), here in jsec's `TLSState` (jtls/internal.h), or the probe state freed while the read is still in flight.
- Repro shape: test/smoke/tls-connect-wait.janet with the client cancelled instead of reset. Wine may hide it, as it hid #10; it needs real windows, which means a pushed CI run.
- The jsec fixes under test, all in the pin (9b57288, 2026-10-18), are fossil tickets (https://code.amlegion.org/jsec/): 6e1a853d70 (crash on external cancellation), 1377def05c and d4cd1f7993 (fiber GC and teardown freed the embedded TLSState; fix 39b8153927 heap-allocates the async TLSState when suspending), c7dd939d28 (pending_read/pending_write stale after cancel) and 12ec930dcd (a stale timeout cancels a later wait).
- 2026-11-24: was task U-AUELWJRZ3ADY3DTE (and before that B-VXL2NOPINUAFHAPV), promoted 2026-11-14 and returned unstarted. Its purpose: Find out whether jsec 0.2.0's cancel and heap-TLSState fixes end the windows exit 127 and lost stdout after cancelling a fiber in a TLS read. Its success criteria, for whoever promotes it again:
  - A smoke check cancels a fiber blocked in a jsec TLS read and requires chirp to exit 0 with its stdout intact.
  - That check runs on the real windows CI runner against the current jsec pin, and its result is in Evidence.
  - If it still fails, the cause is located in jsec or Janet and recorded for upstream.
