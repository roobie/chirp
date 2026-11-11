---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - The test shuts Chrome down so that no Chrome process is left writing the profile before it is removed, without retrying or ignoring the removal error
  - test/wasm/page.mjs passes 30 runs in a row locally against a built site
  - The ci run on main after the fix is green
---

# task/page-test-chrome-shutdown

## Purpose
The wasm page test fails CI with ENOTEMPTY removing Chrome's profile even after Chrome's main process exits (run 43112709457, after all 9 checks passed): Chrome's helper processes still write the profile. The release is blocked on a green CI.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
page.mjs now runs Chrome in its own process group, closes it with Browser.close over the browser websocket, and waits until the group is empty before removing the profile (SIGTERM then SIGKILL to the group as fallback). Done; awaiting the ci run on main.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Built linux-x64 and wasm32-wasi with tools/build/container.sh, site with chirp site/build.janet --wasm. Old teardown: CHROME=chromium node page.mjs out/site x30 gave 30/30 passes, so the ENOTEMPTY race did not reproduce locally. New code, same loop: 30/30 pass, no SIGTERM/SIGKILL escalation needed in any run, no chromium process of the runs left afterwards. The ci run on main is still to check.
- review: the wait after SIGKILL is now bounded (3x grace) and fails naming the group and the profile, instead of hanging the job

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] learning: the main chrome pid exiting does not mean the profile is quiet; helper processes (network service, crashpad, zygote) outlive it and keep writing. A test that owns a browser profile should put the browser in its own process group, ask it to close over CDP (Browser.close on the browser socket), and wait for the group to be empty before deleting the profile.

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
