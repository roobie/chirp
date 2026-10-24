---
status: accepted
date: 2026-10-24
read_if:
  - changing what leakcheck flags
  - adding a leakcheck exemption
refs:
  - tools/leakcheck/leakcheck.janet#build-needles
  - tools/leakcheck/rules.jdn
  - tools/leakcheck/allow.jdn
---

# D-54W72MHWZBDDVE4V Leak check: generic rules as data, host values read at runtime

## Context
The repo is public. A host-specific detail (a token env var name in AGENTS.md) got committed and only a reviewer noticed. The checker that catches such leaks must not contain host-specific values itself.

## Decision
Generic shapes (home paths, `~/` paths) and exemptions are kept as data. This host's own home path, username, hostname and secret-looking env vars (names and values) are read from the environment each time the check runs. The check is written in Janet and blocks the commit.

## Why
Hard-coding this host's values would leak them in the checker itself, and would miss other contributors' machines. Reading them at runtime protects every machine without storing anything about any of them. Keeping rules and exemptions as data lets people change them without touching the logic. Janet fits because the project already depends on it, and its PEGs are themselves data, so the rule file needs no regex dialect. The check blocks instead of warning, because once a leak is pushed to a public repo it cannot be taken back.

## Consequences
On another machine or in CI, only the generic rules apply until that machine's own values are present. Exemptions may quote generic matches, never a real value of this host. Secret values are redacted in the output.
