---
date: 2026-10-24
read_if:
  - making HTTP requests from chirp's own modules
  - changing the spork-https overlay
refs:
  - src/chirp/update.janet#fetch
---

# L-OFSXUYK57K7GM4JD the update module sees upstream spork-https, not the overlay, so it sets its own User-Agent

## Observation
The spork-https overlay takes effect only for user code. chirp's own modules, such as `update.janet`, get plain upstream spork-https, which sends no default User-Agent, and GitHub rejects requests without one. That is why its `fetch` sets the header itself.

## Why it matters
Any future built-in module that does HTTP must set its own headers too, or import the overlay explicitly. Do not assume the overlay's defaults apply there. This stops being true if the overlay is ever applied to chirp's own modules as well.
