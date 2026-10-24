---
status: accepted
date: 2026-10-24
read_if:
  - adding a bundled component or its license
  - moving build data between jdn files
refs:
  - tools/build/notices.jdn
  - tools/build/image.janet
---

# D-KPP2PSBZKFSROC44 Notice sources live in notices.jdn, apart from config.jdn

## Context
The list of license texts is build data. config.jdn was the natural home, but the image-building process reads config.jdn, and adding the list there moved the binary's hash (B-U6C4GF5ICCTMVVBL).

## Decision
The notice sources live in their own notices.jdn, which only build.janet reads.

## Why
Keeping them in config.jdn would make every license edit a binary change, and the binary would no longer depend only on what it contains. Fixing the image's sensitivity to config.jdn first would be better in principle, but its cause is unknown and it shouldn't block the release.

## Consequences
Data the image does not need should stay out of config.jdn while B-U6C4GF5ICCTMVVBL is open. A new bundled component needs an entry in notices.jdn, or its license is missing from releases.
