---
created: 2026-11-02
---

# B-4KZP4G546WIPPIBT Docstring snippets in --help serve keep their backticks and line breaks

## Why
In `chirp --help serve`, a docstring hit shows its snippet with its backticks and line breaks, while topic snippets are plain text after U-7NTYGOQFXGEEDBHL. Low priority; do it if it bothers anyone.

## Notes
Docstrings use Janet's doc conventions, not Markdown, so md4c would misread them; something like `doc-format` without its colour codes fits better.
