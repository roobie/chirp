---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-25
success_criteria:
  - (import yaml) works in chirp with nothing on disk; yaml/decode and yaml/encode turn YAML text into Janet data and back
  - Scalars resolve by the YAML 1.2 Core schema, so `no` and `on` stay strings and quoted scalars are always strings
  - Anchors, aliases and `<<` merge keys work, and expanding aliases is capped so an alias bomb fails with an error
  - Encoding then decoding a value gives the same value, and encode output is deterministic
  - libyaml is pinned in pins.jdn, appears in NOTICES, the README table and CHANGELOG Unreleased, and a yaml smoke check passes on all four targets in CI with matching hashes
---

# task/yaml

## Purpose
Scripts read and write YAML more than any other config format (CI workflows, Kubernetes, compose files, front matter), and chirp has no YAML. This task adds it, so the battery is no longer missing.

## Scope
In: a `yaml` module built from a pinned yaml/libyaml and a small native binding that chirp owns; decode, decode of multi-document streams, and encode; the build wiring, notices, docs, changelog and smoke check.
Out: round-trip editing that keeps comments and layout (B-7H6ASKHIBTAYW7NL); YAML 1.1 type resolution (`yes`/`no` booleans, sexagesimal numbers).

## Context & constraints
- BR picked libyaml with a chirp-owned binding (2026-10-25). The only Janet YAML library, brandonchartier/janet-yaml, is GPL-3.0, which would make the chirp binary GPL (D-UQZLUV7LGGRXHXPJ). A pure-Janet subset would be a partial YAML that chirp owns forever. libfyaml is larger and its Windows build is unproven.
- libyaml is MIT, mature and rarely changes, so the pin rarely moves; the binding is the only code chirp owns.
- libyaml only tokenises scalars. Resolving them to types is the binding's job, which is how the Core schema is enforced.
- The API follows spork/json, chirp's other data battery, so the two read alike.
- Pins and natives follow D-ZOBE3ZBK764B22JY, D-2V3JOY5TUAMLRJAE and D-MNNDC6PNBUNZXT7O; notices follow D-KPP2PSBZKFSROC44; the smoke check follows D-DPSCZ2KCZA4UB7YM. L-AGD7ZVHWYRGFIEDF and L-NIHSWVXW4SAVWOB4 apply to reproducibility.

### Origin
Promoted from backlog: B-IUK7YUKKWUN5IWUU Bundle a YAML parser and emitter

## Now
Implementation reviewed and committed; CI on all four targets is the remaining proof.

## Next
- Watch CI: builds a/b, hash compare, leakcheck, yaml smoke on every target.
- Install the green linux-x64 artifact, harvest, finalize.

## Evidence
- Local linux-x64 container build: every smoke check passes, including `ok yaml` (Core schema scalars, merge key, aliases, decode-all, round trip, sorted keys, alias bomb and unknown tag rejected).

## Harvest
- [ ] decision: bundle libyaml behind a chirp-owned binding, with Core schema resolution and capped alias expansion
- [ ] learning: gensym reuses names the collector freed, so GC timing (driven by out-dir path length) moved gensym names in the image; image.janet holds the collector off
- [ ] decision: natives.jdn `:repo-sources` lets a binding chirp owns build against a pinned library without copying it into the pin

## Log
- 2026-10-25 CI 40143523124: all builds and smokes green, compare failed on every target; only gensym names differed. Fixed in image.janet.
- 2026-10-25 initialized from B-IUK7YUKKWUN5IWUU; BR chose libyaml with a chirp-owned binding
- 2026-10-24 phase initialize → execute
