---
created: 2026-11-04
---

# B-LXVEZMLKF5VJOQZQ Point #4 and #6 at what spork already bundles

## Why
GitHub #4 asks for a tabulate-like table formatter and #6 for a zod or Typebox-like parse-don't-validate module. chirp already bundles `spork/misc` `print-table` and `spork/schema` (`validator`, `predicate`), so both can probably be answered with a pointer rather than new code.

## Notes
- Reply on each issue with a short example, and close it unless the reporter needs more: print-table has no alignment, number formatting or output formats (markdown, grid) like tabulate's, and spork/schema validates without coercing or building typed results.
- If a gap matters, it becomes its own backlog item. Prefer an upstream spork change to a chirp-owned module.
- A task-to-module help topic (B-S3NXI7Y7RE7GGQPI) would make both easier to find.
