---
date: 2026-11-10
read_if:
  - testing a page in headless Chrome
  - a page check sees the page still loading
refs:
  - test/wasm/page.mjs
---

# L-LJQX4CGWVP5BOPVZ Headless Chrome's --dump-dom does not wait for a wasm page; drive it over the DevTools protocol

## Observation
`google-chrome --headless=new --dump-dom --virtual-time-budget=15000` dumped the try page while its status still read "Loading chirp.wasm…": virtual time does not wait for compiling a module or for a worker. Launching Chrome with `--remote-debugging-port=0`, reading the port from its "DevTools listening on" line and polling `Runtime.evaluate` over Node 22's built-in WebSocket worked first time, with no npm package.

## Why it matters
A page check needs to wait on the page's own state (here `data-exit` and `data-count` attributes the page sets when done), not a time budget. The driver is about 60 lines in test/wasm/page.mjs and can be reused for any page.
