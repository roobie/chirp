---
status: accepted
date: 2026-10-29
read_if:
  - changing chirp --help serve
  - changing how help is searched
refs:
  - src/chirp/help.janet#index
  - src/chirp/help-serve.janet#serve
---

# D-T52C67MPJMJZQ5RK help serve builds one search index per process and reuses the site stylesheet

## Context
Issue #1: a browser UI over the offline help. D-6MHEZUS5HUJXWV6A builds the FTS5 index at runtime from baked-in entries. A CLI query builds its index once and exits, but a server would rebuild it on every keystroke. BR wanted the web pages to look like the project site.

## Decision
The server builds the index once at start, and the CLI and the server share the same index and search code. The site's stylesheet is baked in at build time, like the help topics, and both the site and serve use it.

## Why
Rebuilding the index per request would cost more than the search itself. A second search path for the server would drift from `--help query`. A separate stylesheet for serve would drift from the site. Reading the CSS from disk at runtime would break "nothing on disk" and reproducible builds.

## Consequences
A style change shows up on both the site and serve, so check both. Serve is bound to localhost unless `--host` is given, which keeps exposing the help to the network an explicit choice.
