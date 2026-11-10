---
status: accepted
date: 2026-11-10
read_if:
  - changing dev-proc's exit codes or its errors
  - running dev-proc from a program over many directories
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#EXIT-NO-WORK-DIR
  - .agents/skills/dev-proc/scripts/dev-proc.janet#EXIT-NOT-FOUND
---

# D-3NN3S4SKFDHQPNZN dev-proc's exit code tells no work dir and not found apart from failure

## Context
Programs such as viewers run dev-proc over many directories and units, and could only tell an ordinary answer from a failure by matching stderr text.

## Decision
Exit 3 means no work dir here and exit 4 means a unit or record named by a well-formed id or label is not active; 1 and 2 stay any other failure. A root the operator named that does not exist, a malformed or ambiguous ref, and a unit's own recorded parent that is gone are failures, not 3 or 4. The commit hooks keep exit 0 in a repo without a work dir.

## Why
Most directories have no dev-proc work, and a unit can close between a viewer listing it and opening it; both are normal answers, so they need a contract that survives rewording a message. A named root or a typo is the caller's mistake, which a program should surface rather than read as "nothing here". Keeping the hooks quiet means a repo that does not use dev-proc never notices it.

## Consequences
The codes are a published contract: 3 and 4 cannot change meaning. check and find, which used to answer ok with zero roots, now exit 3 there.
