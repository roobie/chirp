---
status: accepted
date: 2026-10-24
read_if:
  - working on the HTTP client or server
  - spork-https README says it needs a modified spork
refs:
---

# D-2SHG5CGZYE2DZCQG HTTPS via llmII/spork-https on upstream spork

## Context
chirp needs an HTTPS client and server, including mTLS, written in pure Janet on top of jsec (D-GNHGVHYBQ7SLBAIU).

## Decision
Bundle llmII/spork-https and run it on upstream spork.

## Why
It is pure Janet and covers client, server and mTLS. Its README says it needs a modified spork, but that is out of date: upstream `spork/http.janet` already has `:stream-factory`, and spork-https's own deps point at upstream. So it fits D-ZBIADZDYXYPWLX5L.

## Consequences
If spork-https stops working on upstream spork, fix it upstream or in spork-https. Do not fork spork.
