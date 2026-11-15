---
created: 2026-10-25
---

# B-U4PHFF5M2IYP4GRX Bundle an XML parser

## Why
XML still turns up in scripting work: RSS and Atom feeds, SVG, Maven and .NET project files, sitemaps, JUnit test reports and older APIs. chirp has no way to read it.

## Notes
- yxml is a tiny MIT streaming parser in C, a good fit for a chirp-owned binding over a pin. Canonical repo `https://code.blicky.net/yorhel/yxml.git`, untagged since 2020, so pin a commit. About 1,200 lines of C.
- Layering (BR, 2026-11-15): a pull parser first, then a DOM-style tree API built on it. The pull layer is the only C; the tree (tag, attributes, children) and a writer with escaping are Janet over it, so large files never need the whole tree.
- Rough size: like md4c's binding, a day or so for the pull layer, its smoke test, help, notice and decision; the tree layer after it is smaller.
- First consumer: the fossil feed watcher (B-DE4OCJCKANMSZ75T). lexbor cannot stand in, since HTML parsing treats RSS `<link>` as void.
- Never resolve external entities or DTDs (XXE); yxml does not, which is part of its appeal.
- Namespaces and a small query helper (path-style lookup) are worth weighing against scope.
