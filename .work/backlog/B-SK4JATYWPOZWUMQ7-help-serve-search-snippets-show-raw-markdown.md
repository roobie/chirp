---
created: 2026-10-29
---

# B-SK4JATYWPOZWUMQ7 help serve: search snippets show raw markdown

## Why
On the serve results page, the FTS5 snippet is escaped raw text, so code fences, backticks and newlines show as-is. It is safe but hard to read.

## Notes
Either strip markdown syntax from snippets for the web, or highlight the matched terms (snippet() can mark them) and render those marks.
