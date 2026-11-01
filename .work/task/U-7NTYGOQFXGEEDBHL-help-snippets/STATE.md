---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-01
success_criteria:
  - A --help serve search for a topic word returns snippets with no backticks or fence markers and the match inside <mark>; the help-serve smoke check covers it
  - --help query snippets carry no markdown syntax and no marker bytes
  - CI builds all four targets twice with matching sha256 and the smoke checks pass
---

# task/help-snippets

## Purpose
Search snippets in --help serve and --help query read as text: no markdown syntax, and the matched words highlighted on the web page.

## Scope
In: index markdown topics as plain text (md4c, then lexbor's text) and mark matches in serve snippets.
Out: docstrings, which are shown as raw text on their own pages and keep their backticks.

## Context & constraints
The entries are collected at image build (D-6MHEZUS5HUJXWV6A), so the plain text is computed there, not per query. CLI and serve share one search function (D-T52C67MPJMJZQ5RK); the marks are a parameter, so only serve gets them.

### Origin
Promoted from backlog: B-SK4JATYWPOZWUMQ7 help serve: search snippets show raw markdown

### Why
On the serve results page, the FTS5 snippet is escaped raw text, so code fences, backticks and newlines show as-is. It is safe but hard to read.

### Notes
Either strip markdown syntax from snippets for the web, or highlight the matched terms (snippet() can mark them) and render those marks.


## Now
Done locally; waiting on CI.

## Next
- Push, check the CI run, finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- New assertions in help.janet and help-serve.janet fail with the installed chirp (topic snippet shows `:trusted-cert` with backticks) and pass with a local linux-x64 build; the rest of the smoke suite passes.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] backlog: docstring snippets in --help serve still show their backticks and line breaks; render docstrings like Janet's doc-format if that bothers anyone

## Log
- 2026-11-01 initialized
- 2026-11-01 phase initialize → execute
- 2026-11-01 topics indexed as plain text; serve snippets mark matches; smoke checks; changelog
