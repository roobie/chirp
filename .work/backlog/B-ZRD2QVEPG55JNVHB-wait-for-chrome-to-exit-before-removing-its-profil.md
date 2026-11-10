---
created: 2026-11-10
---

# B-ZRD2QVEPG55JNVHB Wait for Chrome to exit before removing its profile in the wasm page test

## Why
The wasm CI job fails now and then at teardown: the page test removes Chrome's profile directory right after killing Chrome, while Chrome is still writing to it, and the removal fails with ENOTEMPTY. It has failed main (35c02d9) and PR #18 that way; each time a rerun passed. A flaky job teaches everyone to rerun instead of read.

## Notes
- refs: test/wasm/page.mjs, the teardown after the page checks.
- Wait for the child's exit event before removing the profile; a retrying removal would hide the race rather than end it.
- Meant for a later PR that collects small fixes.
