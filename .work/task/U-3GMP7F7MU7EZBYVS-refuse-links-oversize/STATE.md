---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-10
success_criteria:
  - A committed symlink named STATE.md, or a record file, is not read and shows as a problem in check, status and status --json
  - A symlink standing for a type, unit, backlog, decisions or learnings directory is not followed and shows as a problem
  - A document over the size cap, or a fifo or device in a document's place, is refused as a problem without being read whole or opened
  - A team work dir found by searching upward whose real path is outside the repo is refused; an explicit --root, DEV_PROC_ROOT or dev-proc.root outside it still works
  - A normal tree loads as before, and the dev-proc, skillcheck and leakcheck tests pass
---

# task/refuse-links-oversize

## Purpose
Over a checkout that is not trusted, a committed symlink or a huge file makes dev-proc read what is outside it or exhaust memory (chirp issue 15). The rules belong in dev-proc, not in every consumer.

## Scope
In: one loader helper that reads a document safely; link and size checks while loading a root; refusing a team work dir that leads out of the repo; tests, SKILL.md, CHANGELOG, site page.
Out: refs read by check (source files, where symlinks are legitimate); writes through a symlinked STATE.md beyond refusing to read it.

## Context & constraints
Roots named by the operator (--root, DEV_PROC_ROOT, dev-proc.root) stay exempt from the work-dir rule. The cap is a constant, never read from the checkout.


## Now
Implemented and tested; awaiting review.

## Next
- Owner: judge the 1 MiB cap; review; finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- dev-proc, find, frontmatter tests pass; new tests cover symlinked STATE.md and record, symlinked unit/type/record dirs, oversize (cap+1 refused, cap accepted), fifo, .work leading outside refused, explicit --root/DEV_PROC_ROOT/dev-proc.root accepted, in-repo .work link accepted. D-JYZH36C56HAGEIHI records the design.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] backlog: check-ref reads a ref's source file whole and through links (needed for symbol lookup); bound it for untrusted checkouts without breaking linked skill dirs

## Log
- 2026-11-10 initialized
