---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-01
success_criteria:
  - chirp --help query os/spawn, spork/getline and table? exit 0 and list that binding first; a smoke check covers it
  - Documented FTS5 syntax (quotes, *, OR/NOT, column filters, NEAR) still works
  - CI builds all four targets twice with matching sha256 and the smoke checks pass
---

# task/help-query-punctuation

## Purpose
chirp --help query finds names with punctuation other than a hyphen, such as os/spawn, spork/getline or table?, instead of failing with an FTS5 syntax error.

## Scope
In: the query rewrite in help.janet (any word holding punctuation becomes a phrase; a word-initial `:` is punctuation), the help text, smoke checks, changelog.
Out: tokenizer changes (L-BRH7VAMIKGUSTHKF).

## Context & constraints
Found while looking up spork/getline for B-WMHIKUYY6NBOTTVB. The hyphen-only rewrite came from task help-query-hyphen; documented FTS5 syntax in help/help.md must keep working.


## Now
Done locally; waiting on CI.

## Next
- Push, check the CI run, finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Installed chirp: os/spawn, spork/getline, net/server, string/split OR peg and os/spawn :cd all fail with fts5 syntax errors. Local linux-x64 build: each returns hits, the binding first for os/spawn and table?; title:server, id:sh, cert*, OR/NOT, NEAR and quoted phrases unchanged; full smoke suite passes.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-01 initialized
- 2026-11-01 phase initialize → execute
- 2026-11-01 --help query: words holding punctuation search as phrases; word-initial : too; smoke checks, help text, changelog
