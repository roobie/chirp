---
date: 2026-10-29
read_if:
  - writing a spork/http handler
refs:
  - src/chirp/help-serve.janet#serve
---

# L-R56KUMI6ZJCDPIWX spork/http drops the connection when a handler throws

## Observation
When a handler raises an error, spork/http closes the connection without a response. The browser sees a network error instead of an error page. Serve catches errors around its routing and answers 500.

## Why it matters
Every spork/http handler needs its own catch-all to give a status code. This stops being true if spork adds a default 500.
