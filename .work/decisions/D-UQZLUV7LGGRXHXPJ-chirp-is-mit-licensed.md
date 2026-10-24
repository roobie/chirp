---
status: accepted
date: 2026-10-24
read_if:
  - choosing a license for new files or bundled code
  - writing release notices
refs:
  - LICENSE
---

# D-UQZLUV7LGGRXHXPJ chirp is MIT licensed

## Context
chirp is about to publish binaries, and the repo had no license, so nobody could legally reuse its build tooling or redistribute its releases. Everything it bundles is permissive: Janet and spork are MIT, jsec and spork-https are ISC, OpenSSL 3 is Apache-2.0, and musl is MIT.

## Decision
chirp's own code and its releases are under the MIT license (BR, 2026-10-24). Bundled components keep their own licenses, and releases carry those texts.

## Why
MIT matches Janet and spork, which chirp builds on and whose users already know it, and it is compatible with every bundled license. ISC would mean the same thing but is less familiar to Janet users. Apache-2.0 would add a patent grant, but also NOTICE handling for chirp's own code, which buys a build-tooling repo little.

## Consequences
A new bundled dependency must have a license compatible with MIT redistribution, and its text must reach the release notices.
