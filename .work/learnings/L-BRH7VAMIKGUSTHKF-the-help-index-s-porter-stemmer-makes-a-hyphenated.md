---
date: 2026-11-01
read_if:
  - help search ranks the wrong entries first
  - changing the help index tokenizer
refs:
  - src/chirp/help.janet#search
  - src/chirp/help.janet#index
---

# L-BRH7VAMIKGUSTHKF The help index's porter stemmer makes a hyphenated phrase match its unhyphenated cousins

## Observation
unicode61 splits `spork-https` into `spork https`, and porter stems `https` to `http`, so the phrase also matches every spork/http entry. Those mention spork and http often, so bm25 put them ahead of the spork-https bindings (rank 12 and below). `search` ranks literal id or title hits first to make up for it.

## Why it matters
Dropping the stemmer or adding `-` to tokenchars would fix this case but break others (`certificate` finding `certificates`, `update` finding `self-update`), so the literal-hit ranking is the cheaper lever.
