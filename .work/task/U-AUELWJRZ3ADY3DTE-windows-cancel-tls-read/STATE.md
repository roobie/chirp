---
phase: initialize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-14
success_criteria:
  - A smoke check cancels a fiber blocked in a jsec TLS read and requires chirp to exit 0 with its stdout intact.
  - That check runs on the real windows CI runner against the current jsec pin, and its result is in Evidence.
  - If it still fails, the cause is located in jsec or Janet and recorded for upstream.
---

# task/windows-cancel-tls-read

## Purpose
Find out whether jsec 0.2.0's cancel and heap-TLSState fixes end the windows exit 127 and lost stdout after cancelling a fiber in a TLS read.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-VXL2NOPINUAFHAPV Windows chirp exits 127 and loses stdout after cancelling a fiber in a jsec TLS read

### Why
On windows, `ev/cancel` of a fiber blocked in a jsec TLS read, with its zero-byte probe in flight, makes chirp exit 127 after main returns, and stdout is lost. A script that times out a TLS read reports failure and loses its output. Seen 2026-11-04 in slice windows-tls-connect; split out of B-5AUA2Q7IH5DP2ZME, where it sat inside an upstream-filing item.

### Notes
- Suspects: the IOCP state layout already patched for accept (L-ZDKYOLHCJKJJIE3R), here in jsec's `TLSState` (jtls/internal.h), or the probe state freed while the read is still in flight.
- Repro shape: test/smoke/tls-connect-wait.janet with the client cancelled instead of reset. Wine may hide it, as it hid #10; it needs real windows, which means a pushed CI run.


## Now
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

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
- 2026-11-14 initialized
