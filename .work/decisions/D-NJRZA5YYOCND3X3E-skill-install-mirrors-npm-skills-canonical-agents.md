---
status: accepted
date: 2026-10-29
read_if:
  - adding an agent directory or a skill to chirp --<skill> --install
refs:
  - src/chirp/skills.janet#install-skill
  - src/chirp/chirp.jdn
---

# D-NJRZA5YYOCND3X3E Skill install mirrors npm skills: canonical .agents/skills plus agent links

## Context
Issue #2 asked for the dev-proc skill to be installable from the chirp binary alone. Every agent tool looks for skills in a directory of its own.

## Decision
One canonical copy goes under `.agents/skills/<name>`, in the project or, with `-g`, in home. Each agent directory gets a relative link to it, and falls back to a copy where it cannot link. The skills, the canonical dir and the agent dirs are data in chirp.jdn.

## Why
BR chose the npm `skills` layout so that projects using both tools look the same. The alternatives were a copy per agent directory, which drifts as each copy is edited separately, and writing only to `.claude/skills`, which ties the skill to one agent. A relative link keeps a project working after it is moved or checked out somewhere else.

## Consequences
Supporting another agent, or bundling another skill, is a change to chirp.jdn alone. Windows usually gets copies, because Janet cannot make junctions; see D-WDOKPQ422TKMQ3RO for why reinstalling over those copies still works.
