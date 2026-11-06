---
status: accepted
date: 2026-11-06
read_if:
  - adding, moving or repointing a skill in this repo
  - moving or repointing the dev-proc skill in this repo
refs:
  - .agents/skills/dev-proc/SKILL.md
  - .agents/skills/chirp-release/SKILL.md
  - tools/skillcheck/skillcheck.janet#problems
supersedes:
  - D-RFOFYVBEDCXF6BZW
---

# D-HLIOIUOA4NCCKNJI Every skill in this repo lives in .agents/skills, with .claude/skills a committed link

## Context
chirp bakes the dev-proc skill into its image from this repo's files, and `chirp --dev-proc --install` lays a project out as D-NJRZA5YYOCND3X3E describes. The repo also had a skill of its own written straight into `.claude/skills` (asking-astra, since deleted), and gained chirp-release.

## Decision
Every skill in this repo lives in `.agents/skills/<name>`, and `.claude/skills/<name>` is a committed relative link to it. dev-proc's link is made by running the installer here.

## Why
BR wanted to dogfood the installer, so this repo uses the exact layout it gives other projects, for every skill and not only the shipped one. The build source, the hooks and the site read one real directory, and an agent other than Claude finds the same files. A skill written only into `.claude/skills` ties it to one agent and makes the repo look unlike an install.

## Consequences
Hooks, the site build and the records point at `.agents/skills`. Running the installer in this repo should always report "up to date"; if it does not, the shipped files and the repo have diverged. A new skill is created under `.agents/skills` and then linked, never the other way round. skillcheck enforces the layout on the index in the pre-commit hook and in CI.
