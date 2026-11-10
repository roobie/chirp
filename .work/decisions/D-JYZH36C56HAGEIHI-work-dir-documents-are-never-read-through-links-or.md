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
dev-proc trusts nothing a checkout's work dir links to or holds. Reading, writing and descending are refused for a link, a file that is not a regular file, a file over the cap, and anything past a per-root byte budget, and each refusal is a problem on the unit, record or root, not an error, so one bad entry hides nothing else. A work dir that dev-proc finds by searching is refused when it is a link or leads out of the repo; one the operator names is their own choice and exempt.

## Why
A viewer or agent runs dev-proc over checkouts nobody vetted. A committed symlink would put a file from outside, or one git ignores (a person's own private root), into status --json, or let new and record write outside the checkout; /dev/zero or a fifo would exhaust memory or hang every run. Each consumer re-walking the tree and capping memory would be many copies of one rule, so dev-proc owns it. The limits are constants in the script because a setting in the checkout would let the checkout lift them. A plain git-ignored work dir stays supported because that is the documented no-history case.

## Consequences
The check looks at the entry before opening it and the read is capped, but Janet has no O_NOFOLLOW, so a concurrent writer that swaps a file for a link between the two can still win; the cap bounds what that costs. The per-root budget bounds the total a root can make dev-proc read, not the time. Both caps are the owner's to tune.
