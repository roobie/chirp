---
date: 2026-10-29
read_if:
  - starting an HTTP server with spork/http
refs:
  - src/chirp/help-serve.janet#serve
---

# L-ZQOSOWA7MIA5RT7K spork http/server sets SO_REUSEPORT, so a taken port binds silently

## Observation
spork's `http/server` opens its socket with port reuse. A second server on a port that is already taken starts without error, and the two processes share the traffic. Serve calls `net/server` with no-reuse and uses spork's connection handler, so a taken port fails at start.

## Why it matters
Any chirp server that should own its port needs the same treatment. This stops being true if spork makes reuse optional on `http/server`.
