---
status: accepted
date: 2026-11-15
read_if:
  - changing anything under .agents/skills/dev-proc
  - dev-proc's own records are not found in this repo
refs:
  - AGENTS.md
---

# D-RFPRKKRRWYW54RHC dev-proc is vendored here from the owner's tools repo; change it upstream

## Context
dev-proc started as a fork inside this repo (D-VZIDK5O2VNATQDCP), so every process change was a chirp commit, CI run, release and reinstall, away from the tools that consume its format.

## Decision
The skill's canonical home is the owner's private tools repo. `.agents/skills/dev-proc` here is a one-way vendored copy. It is changed upstream and synced in, never edited here.

## Why
A process change is then one upstream commit, live when merged. The upstream repo is private, so chirp cannot point at it, and public users still need the skill, which `chirp --dev-proc --install` ships from this copy. Keeping the installer, the site page and the tests here means that path stays covered.

## Consequences
The records about dev-proc's own design moved upstream with their ids. `dig` finds them in this repo's history up to the commit that removed them; the private upstream keeps the live copies. Records here that mention them by id still name the right thing. Records about installing, bundling and the site stay here. Each sync is a commit here that names the upstream commit its tree matches.
