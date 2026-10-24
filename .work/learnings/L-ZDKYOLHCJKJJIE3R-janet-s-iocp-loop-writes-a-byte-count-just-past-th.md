---
date: 2026-10-24
read_if:
  - writing or patching a Janet native that does overlapped I/O on windows
  - a windows-only crash after an async operation completes
refs:
  - tools/build/patches/jsec-iocp-accept-state-padding.patch
---

# L-ZDKYOLHCJKJJIE3R Janet's IOCP loop writes a byte count just past the OVERLAPPED in a native's fiber state

## Observation
On windows, Janet treats any fiber's pending `ev_state` as its private `JanetOverlapped`, which is the OVERLAPPED plus a trailing byte count, and writes that count on every completion. `janet.h` doesn't export that layout, so a native that puts its own field right after the OVERLAPPED has it silently overwritten. jsec kept the accepted socket there. A zero-byte AcceptEx made the handle 0, and every TLS server died on its first connection, both under Wine and on real Windows.

## Why it matters
The symptom ("failed to listen for events: Invalid handle", or a hang) points far from the cause, and linux never shows it. Any native doing overlapped I/O has to reserve that slot. This stops applying if Janet exports `JanetOverlapped` for natives to embed, or stops writing past the OVERLAPPED.
