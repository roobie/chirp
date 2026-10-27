---
created: 2026-10-25
---

# B-7H6ASKHIBTAYW7NL Bundle round-trip Markdown parsing and rendering

## Why
Scripts that maintain docs, changelogs or records need to edit a Markdown file without disturbing the rest of it, for example rewriting one section or ticking a checkbox. Round-trip means that parsing a file and rendering it back unchanged gives the same bytes (BR, 2026-10-25). chirp's help system and the dev-proc port (B-GFASGZA3FO4XHJAV) both handle Markdown sections by hand today.

## Notes
- Front matter should round-trip too, which ties this to YAML (B-IUK7YUKKWUN5IWUU).
- spork/mdz renders Markdown-like markup to HTML and does not round-trip, so it does not cover this.
- md4c is bundled for HTML (U-XHNWANHLCDSBMPPJ). Rebuilding Markdown from its parse events cannot be byte-identical: they carry structure, not spelling (`*` or `_`, ATX or setext, escapes, indentation, blank-line runs, reference definitions are lost). lk's md4c wrapper has the same limit and compares parsed structure, not bytes.
- Approach to spike (BR agreed, 2026-10-27): keep the source bytes and use md4c only to locate nodes. Text callbacks point into the input buffer, so pointer minus base gives offsets; a node's span is its first to last text byte, widened to whole lines for blocks. A no-edit render returns the source; an edit splices only the touched node's bytes. md4c 0.6.0's `MD_FLAG_PRESERVEBLANKLINES` helps place blank runs.
- Risks the spike must settle: nodes without text (`---`, empty code, image-only paragraphs) need a scan for their span; some callbacks may pass synthetic strings (soft breaks, U+FFFD for NUL); an edit inside a quote or list must restore the container's per-line prefix.
- Look for an existing Janet library that keeps source positions or the original text, before writing one.
- Done when parse-then-render is byte-identical on a corpus (this repo's .md files, CHANGELOG.md, the help topics), and an edit changes only the node it touches.
