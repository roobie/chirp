---
created: 2026-11-14
---

# B-5KGECVCNU6SWGW4B make local windows smoke match CI: run-windows.sh mounts the repo and its Wine image has git

## Why
Local Windows smoke under Wine cannot pass the checks that need the repo or git (self-update, dev-proc-install), while the CI windows runner can. A local run therefore never matches CI, and a real Windows regression in those checks is only seen after a push.

## Notes
`test/smoke/run-windows.sh` mounts only `test/smoke`; mount the repo instead, and add git to the Wine image.
