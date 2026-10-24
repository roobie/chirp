---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A chirp script that calls a spork-https client function with no headers sends `User-Agent: chirp/<version>`, the version taken from chirp.jdn
  - A caller-supplied User-Agent, in any letter case, is sent unchanged, and no second User-Agent is added
  - A client given `:tls-opts {:ca "<file>"}` trusts that CA, so it connects with verification on to a local server whose self-signed certificate is in that file
  - The spork-https server and its `:ca` handling are unchanged
  - The smoke suite checks all three client behaviours; CI is green on all four targets with the double build matching
---

# slice/spork-https-overlay

## Purpose
Make the bundled `spork-https` work the way its docs say, without forking it. Today, scripts hit two problems. GitHub's API rejects requests that have no User-Agent. And a client told to trust one CA through `:ca` silently trusts the whole system store.

## Scope
In: a chirp-owned overlay that replaces the client functions in the bundled `spork-https` env; a data entry in chirp.jdn naming the overlay; smoke checks; a decision record.
Out: changes to spork-https, spork or jsec themselves; the server side; plain `spork/http` requests. Filing the upstream reports is out too, because BR said not to file anything for now.

## Context & constraints
- BR chose a transparent overlay over a separate `chirp/https` module (2026-10-24). `(import spork-https)` stays the way to use it, and dropping each fix once upstream lands it breaks no scripts.
- spork-https's `get`/`post`/… call `request` through compiled references, and `request` calls spork/http the same way. Replacing a single binding changes nothing, so every client entry point is wrapped: `request`, `open-stream`, `download`, `get`, `post`, `put`, `patch`, `delete`, `head`.
- jsec clients ignore `:ca` and take `:security {:ca-file …}` (L-CPIUGJI6EY2HEID2). spork-https passes `:tls-opts` and `:stream-opts` to `tls/connect` together, so the mapping applies to both.
- Never fork upstream (D-ZBIADZDYXYPWLX5L, D-2SHG5CGZYE2DZCQG). The overlay is chirp code layered over a pristine pin.
- `(doc …)` on a wrapped function should still show the upstream docstring, plus a note on what chirp adds.

### Origin
Promoted from backlog: B-QCZS5VCEMNVARX34 Fix spork-https documenting :ca for client trust. The User-Agent default was added by BR as usage feedback on 2026-10-24.

### Notes
Smallest repro of the `:ca` problem: about 15 lines of plain jsec. Start `tls/server` on localhost with a self-signed cert written to `ca.pem`, then connect three ways with verification on. `{:trusted-cert pem}` and `{:security {:ca-file "ca.pem"}}` connect; `{:ca "ca.pem"}` fails with `certificate verify failed`. Upstream fixes would be spork-https correcting its docs, and jsec either reading `:ca` on clients or rejecting unknown keys.

## Now
Initialized; next is delegating the code.

## Next
- Delegate the overlay, the chirp.jdn entry and the smoke checks; review them; build linux-x64 locally; push; get CI green.

## Evidence

## Harvest
- [ ] decision: chirp corrects bundled modules with an overlay of replacement bindings, named in chirp.jdn, not with a fork or a separate module

## Log
- 2026-10-24 initialized
- 2026-10-24 User-Agent default added to scope; overlay approach chosen by BR
- 2026-10-24 phase initialize → execute
