---
created: 2026-10-25
---

# B-U4PHFF5M2IYP4GRX Bundle an XML parser

## Why
XML still turns up in scripting work: RSS and Atom feeds, SVG, Maven and .NET project files, sitemaps, JUnit test reports and older APIs. chirp has no way to read it.

## Notes
- yxml is a tiny MIT streaming parser in C, a good fit for a chirp-owned binding over a pin.
- Decode to a simple tree (tag, attributes, children) plus an event or streaming mode for large files; a writer with escaping.
- Never resolve external entities or DTDs (XXE); yxml does not, which is part of its appeal.
- Namespaces and a small query helper (path-style lookup) are worth weighing against scope.
