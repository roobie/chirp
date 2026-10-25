---
created: 2026-10-25
---

# B-R34P4IIPDHRM4KND Bundle an HTML parser with CSS selectors

## Why
BR often writes online checks after a deploy (for example to Cloudflare) to confirm the site serves what it should, and keeps such checks as standing automated tests. That needs real HTML parsing and CSS selectors: matching on raw text is brittle against markup that is valid but formatted differently. With spork-https already bundled, chirp could fetch and assert in one script.

## Notes
- lexbor is a fast, spec-conformant HTML5 parser with a CSS selector engine, Apache-2.0 (compatible with chirp's MIT binary; needs its notice).
- It is large; build only the modules needed (core, html, dom, css, selectors) and check the binary-size cost.
- API to settle: parse, select (all and first), text content, attributes, and maybe outer HTML.
- The smoke check should cover a selector over a parsed document on every target.
