---
status: accepted
date: 2026-10-28
read_if:
  - changing the lexbor API
  - parsing HTML or querying it with CSS selectors in chirp
  - considering another HTML parser
refs:
  - src/lexbor/lexbor.c
  - tools/build/natives.jdn
---

# D-AYM6G4PAISONUDLK lexbor is a chirp-owned binding over its HTML, DOM and selectors modules, with nodes as handles on their document

## Context
Scripts that check what a deployed site serves (BR's standing post-deploy checks, and the Pages site's own tests) matched raw text, which breaks on markup that is valid but formatted differently. They need an HTML parser that repairs markup as a browser does, and CSS selectors to find things.

## Decision
chirp bundles lexbor, building only the modules that parsing and selecting need, and owns a small read-only binding as a module named `lexbor`. A node is a handle that keeps its document alive. Matches come once each, in document order. A selector that does not parse is an error.

## Why
lexbor follows the HTML standard's parsing and has a selector engine of its own, under Apache-2.0, in C99 with no dependencies. Every one of its globals is already prefixed, so unlike md4c nothing needs renaming (L-BVXC557ZOWPP4SN5). Its other modules (encoding, url, style) are left out because nothing needs them, which keeps the cost to about 1 MiB per target. BR chose handles over copying each match into plain Janet data (2026-10-28): handles cost nothing until read and can be searched in turn, and since nothing changes a document a handle cannot go stale. Duplicate matches from a selector list (`a, a.x`) would surprise anyone used to `querySelectorAll`, hence once each in document order. A bad selector failing catches a typo that would otherwise quietly match nothing.

## Consequences
- Documents are read-only from Janet; changing a tree would make handles able to dangle and needs its own design.
- lexbor's memory is outside Janet's GC accounting, so a script parsing many large pages may hold memory longer than Janet's heap size suggests.
- Selectors are parsed on every call; a compiled-selector API can come later if a profile asks for it.
- Apache-2.0 requires lexbor's NOTICE to ship, so it is a separate entry in the notices.
