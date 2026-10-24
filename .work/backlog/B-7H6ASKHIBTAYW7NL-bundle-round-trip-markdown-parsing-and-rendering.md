---
created: 2026-10-25
---

# B-7H6ASKHIBTAYW7NL Bundle round-trip Markdown parsing and rendering

## Why
Scripts that maintain docs, changelogs or records need to edit a Markdown file without disturbing the rest of it, for example rewriting one section or ticking a checkbox. Round-trip means that parsing a file and rendering it back unchanged gives the same bytes (BR, 2026-10-25). chirp's help system and the dev-proc port (B-GFASGZA3FO4XHJAV) both handle Markdown sections by hand today.

## Notes
- Front matter should round-trip too, which ties this to YAML (B-IUK7YUKKWUN5IWUU).
- spork/mdz renders Markdown-like markup to HTML and does not round-trip, so it does not cover this.
- Look for an existing Janet library that keeps source positions or the original text, before writing one.
- Done when parse-then-render is byte-identical on a corpus (this repo's .md files, CHANGELOG.md, the help topics), and an edit changes only the node it touches.
