---
status: accepted
date: 2026-10-25
read_if:
  - changing how YAML is parsed, resolved or emitted
  - considering another YAML library
refs:
  - src/yaml/yaml.c#classify
---

# D-VOBKZC6H4OPIMPQE Bundle libyaml behind a chirp-owned binding

## Context
Scripts meet YAML more than any other config format, and chirp had none. The only Janet YAML library is GPL-3.0, which would make the chirp binary GPL (D-UQZLUV7LGGRXHXPJ).

## Decision
chirp bundles libyaml and owns the binding over it. The binding resolves scalars by the YAML 1.2 Core schema and caps alias expansion and nesting depth.

## Why
libyaml is MIT, mature and rarely changes, so the pin seldom moves and the only code chirp owns is the binding. A pure-Janet parser would be a partial YAML that chirp maintains forever. libfyaml is larger and its Windows build was unproven. libyaml only tokenises scalars, so the binding is the place where types are decided: the Core schema keeps `no` and `on` as strings, which is what YAML 1.2 tools expect and avoids the YAML 1.1 surprises. The caps exist because an alias bomb turns a few hundred bytes into billions of nodes.

## Consequences
YAML 1.1 resolution (`yes`/`no` booleans, sexagesimal numbers) is not offered; the encoder quotes those words so older readers still see strings. The API mirrors spork/json, so changes to one should consider the other. Comment-preserving round trips are out of scope here (B-7H6ASKHIBTAYW7NL).
