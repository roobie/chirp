---
status: accepted
date: 2026-10-29
read_if:
  - moving or repointing the dev-proc skill in this repo
refs:
  - .agents/skills/dev-proc/SKILL.md
---

# D-RFOFYVBEDCXF6BZW This repo's dev-proc lives in .agents/skills with .claude/skills a committed link

## Context
chirp bakes the dev-proc skill into its image from this repo's files, and `chirp --dev-proc --install` lays a project out as D-NJRZA5YYOCND3X3E describes.

## Decision
The skill's source lives in `.agents/skills/dev-proc`. `.claude/skills/dev-proc` is a committed link to it, and that link was made by running the installer here.

## Why
BR wanted to dogfood the installer, so this repo uses the exact layout it gives other projects. That way the build source, the hooks and the site all read one real directory. The alternative, keeping the source in `.claude/skills`, would make this repo the one project that does not look like an install.

## Consequences
Hooks, the site build and the records point at `.agents/skills/dev-proc`. Running the installer in this repo should always report "up to date". If it does not, the shipped files and the repo have diverged.
