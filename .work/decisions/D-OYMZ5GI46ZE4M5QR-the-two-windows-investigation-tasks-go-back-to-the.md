---
status: accepted
date: 2026-11-24
read_if:
  - promoting the windows TLS-cancel or CA-root-source backlog item
refs:
---

# D-OYMZ5GI46ZE4M5QR The two windows investigation tasks go back to the backlog unstarted

## Context
`windows-cancel-tls-read` and `windows-ca-root-source` were promoted on 2026-11-14 and sat in initialize for ten days with an empty Scope and a `TODO` Next, as open units under the project that nobody was working on.

## Decision
Both are deferred: each returns to the backlog with its why, notes and success criteria, and the units are closed (BR, 2026-11-24).

## Why
An open unit says someone is on it. Keeping them open was the alternative, and it made the status tree and every check of open work misleading while the maintainability milestone is what is being worked. Neither is abandoned and nothing was built, so there is no code to revert.

## Consequences
Each needs a pushed run on the real windows runner, so promote one when a session can spend CI runs on it. The backlog items carry the earlier criteria, so promoting is cheap.
