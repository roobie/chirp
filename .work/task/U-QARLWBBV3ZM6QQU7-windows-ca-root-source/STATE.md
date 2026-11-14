---
phase: initialize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-14
success_criteria:
  - Under Wine, with SSL_CERT_FILE naming an empty file, the source that still lets a public HTTPS GET succeed is named, or the GET now fails.
  - The same check runs on the real windows CI runner, and its result is in Evidence.
  - Any source chirp did not choose is removed, or kept with a decision saying why.
---

# task/windows-ca-root-source

## Purpose
Know every source of CA roots a windows chirp trusts, now that jsec 0.2.0 reworked client trust.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-IOPVTTA3XW3OKYXQ Find where chirp on windows finds CA roots when SSL_CERT_FILE is empty

### Why
Under Wine, an HTTPS GET to a public site still succeeded with `SSL_CERT_FILE` pointing at an empty file, so trust comes from somewhere we did not choose. Until we know where, we cannot say which roots a windows chirp trusts, and we cannot say the OS store chirp exports (D-DGT7DONSVJESO5FV) is the only source.

### Notes
Verification itself is on: a self-signed certificate is rejected with `certificate verify failed`. Suspects are jsec's CA path probing and OpenSSL's compiled-in `--openssldir=/etc/ssl`, which Wine maps to the container's real `/etc/ssl`. Check on real windows too.
- 2026-11-05: windows chirp now exports the ROOT store and real windows CI passes https-get without a hand-set bundle. The likely extra source is still OpenSSL's `--openssldir=/etc/ssl` hash dir, which Wine maps to the container's store (L-OO7ZGOBI22DEUO5R); unconfirmed on real windows.


## Now
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-14 initialized
