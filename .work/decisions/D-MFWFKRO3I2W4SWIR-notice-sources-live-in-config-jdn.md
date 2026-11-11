---
status: accepted
date: 2026-11-11
read_if:
  - adding a bundled component or its license
  - moving build data between jdn files
refs:
  - tools/build/config.jdn#:notices
  - tools/build/image.janet
supersedes:
  - D-KPP2PSBZKFSROC44
---

# D-MFWFKRO3I2W4SWIR Notice sources live in config.jdn

## Context
D-KPP2PSBZKFSROC44 kept the list of license texts out of config.jdn because adding it there moved the binary's hash. The cause turned out to be gensym reuse under collector timing in the image process, not the data itself, and holding the collector off during the image build closed it (L-2H7SFLEMCU2MPRZN). A measurement then showed unread config.jdn data no longer changes the image.

## Decision
The notice sources live in config.jdn under :notices, with the documentation of the entry format beside them. notices.jdn is gone.

## Why
The reason for the split no longer holds, and two files for build data cost a place to look and a rule to remember for nothing. Owner's call: the split is not needed.

## Consequences
A new bundled component needs an entry in :notices, or its license is missing from releases. License edits no longer have to be kept away from the image process by file placement; the image build's collector hold is what keeps the binary stable.
