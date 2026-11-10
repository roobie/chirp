---
status: accepted
date: 2026-11-10
read_if:
  - changing how dev-proc reads a work dir
  - running dev-proc over a checkout that is not trusted
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#read-doc
---

# D-JYZH36C56HAGEIHI Work dir documents are never read through links or past a size cap

## Context
Work dirs arrive in checkouts that may not be trusted, and are read on every run.

## Decision
The loader trusts nothing a checkout's work dir links to or holds. One helper, read-doc, reads every work-dir document; load-root enters directories only through entry-kind. A refusal is a problem on the unit, record or root, not an error, so one bad entry hides nothing else.

## Why
A viewer or agent runs dev-proc over checkouts nobody vetted. A committed symlink would put a file from outside, or one git ignores, into status --json; /dev/zero or a fifo would exhaust memory or hang every run. Each consumer re-walking the tree and capping memory would be many copies of one rule, so dev-proc owns it. The size cap is a constant in the script because a setting in the checkout would let the checkout lift it.

## Consequences
Roots the operator names are exempt, since they are their own choice. Refs checked by check-ref read source files, where symlinks are legitimate, and are not covered.
