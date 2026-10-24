---
status: accepted
date: 2026-10-24
read_if:
  - bumping an upstream version
  - adding a bundled dependency
refs:
---

# D-ZOBE3ZBK764B22JY Pins are one data file of upstream commits

## Context
chirp builds from pinned upstreams (D-ZBIADZDYXYPWLX5L): janet, spork, jsec, spork-https, OpenSSL, plus the build image. A pin bump should be a small change that is easy to review.

## Decision
All pins live in a single data file. Each source is identified by repository and full commit hash, and the build image by digest.

## Why
A commit hash identifies the content itself, so it pins and verifies in one value. Release tarballs would need a separate checksum, and GitHub's generated archives are not guaranteed to stay byte-stable. Keeping the pins as data separate from build logic means a bump touches only content, and it shows up in review as a one-line diff.

## Consequences
Fetching needs git. Every input that affects the output must be in this file, or a reproducibility failure will be hard to explain.
