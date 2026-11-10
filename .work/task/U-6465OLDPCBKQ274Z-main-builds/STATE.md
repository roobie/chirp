---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-10
success_criteria:
  - A successful CI run of a push to main deploys the site with latest/ holding a signed release-shaped tree and a page naming its version and commit
  - release.yml and pages.yml share one tested layout-and-sign script; the release layout is unchanged
  - The site checker, leakcheck, skillcheck and the script tests pass locally
---

# task/main-builds

## Purpose
Each push to main builds chirp and publishes the binaries as a signed release-shaped latest tree on the Pages site, with a plain page for humans

## Scope
In: one layout-and-sign script shared by release.yml and pages.yml; pages.yml publishing after a successful CI run of a push to main; a latest/ tree and a Main build page on the site; docs and records.
Out: making main builds distinguishable by version (backlog B-DDS77NF4GPLATVIL); keeping a history of main builds.

## Context & constraints
GitHub immutable releases are on, so the tree lives on the Pages site. The client reads, through a channel that picks a base and a key, base/latest/download/SHA256SUMS{,.sig} and base/download/v<version>/<file>. release.yml's output must stay exactly as it was. See D-6NWFV37OBOERI3AF.


## Now
Done pending owner review; nothing pushed

## Next
Owner: review, set github-pages environment rules, push

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- tools/release/layout.test.janet passes (release layout, tag check, wrong/missing key, mirror tree)
- chirp built in a container with the channel code: smoke self-update (incl. --channel: unit trust separation both ways, a tree signed by another key refused, unknown channel refused, --key override), help, cli-help, changelog, help-examples pass. main-build-key.pem is the owner's real public key; its private half was never here, so a tree signed with it is untested.
- Local: layout.test, cut.test, leakcheck all + test, skillcheck + test pass; site built with --main-build from a throwaway-key tree (fake artifacts) and site/check.janet passes on 17 pages, 16 without the tree. Not run: the workflows (no actionlint, no GitHub), a live --self-update against the tree (localhost blocked here), a real wasm build.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: D-6NWFV37OBOERI3AF recorded (main builds on Pages, signed with a separate main-build key trusted through --channel main)
- [ ] backlog: B-DDS77NF4GPLATVIL recorded (every main build reports the same -dev version)
- [ ] decision: D-7TDUEHUOFXPTSQCE recorded; it supersedes D-ME7B5XOAG245FN65 (the whole site is published from main on every green push)
- [ ] learning: os/spawn :env is not applied by this chirp with flags :pe, so tests set the variable with os/setenv; a relative import (import ./sign) works from a chirp script

## Log
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
- 2026-11-10 layout.janet lays out and signs a release for any key; sign.janet takes --key-env
- 2026-11-10 release.yml calls the layout script; CI runs its test
