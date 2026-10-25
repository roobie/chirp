---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-25
success_criteria:
  - A bundled module provides an insertion-ordered map type, where `get`, `put`, `in`, `keys`, `values`, `pairs`, `eachp`, `length` and printing work as on a table. Re-putting a key keeps its place, and putting nil removes it
  - '`yaml/decode` takes an opt-in flag that returns ordered maps for mappings, and `yaml/encode` writes an ordered map in its own order'
  - '`json/decode` takes an opt-in flag that returns ordered maps, and `json/encode` writes them in order. Without the flag, both still run spork''s own code and give the same output as upstream'
  - A decode then encode round trip keeps key order for JSON and YAML documents, shown by tests and a smoke check on every target's native runner
  - The ordered JSON decoder gives the same values as spork's decoder on a shared corpus, and the corpus includes escapes, numbers, nesting and bad input
  - dev-proc's front matter uses the ordered decode, and its text scan for key order is removed
  - CI builds every target twice with matching sha256
  - README and CHANGELOG describe the type and both flags
---

# slice/ordered-map

## Purpose
Scripts that rewrite JSON or YAML files a person maintains must keep the keys where the author put them, or every edit becomes a noisy diff. Neither Janet nor any Janet package offers that, so chirp supplies it once, as a type every encoder can honour.

## Scope
In: a chirp-owned ordered map type in C. An ordered option in the yaml module, and in the json overlay for decode and encode. The parity corpus for the ordered JSON decoder. dev-proc switching to the ordered decode.
Out: toml and jdn support (backlog if wanted). Changing the default, unordered behaviour of any decoder. Proposing insertion-ordered tables to Janet upstream (backlog).

## Context & constraints
- BR chose an opaque ordered map type over keeping the order hidden in a prototype, over arrays of pairs, and over ordering by default, as the option with the least tech debt (2026-10-25). With the hidden-order shape, any copy would silently lose the order. Pairs would push lookup helpers into every script. Ordering by default would break the overlay's promise that scripts are unaffected.
- Nothing exists to reuse. Janet core has no ordered table: janet-lang/janet#925 was closed in 2022, with bakpakin saying "for tables maybe". spork/json and six third-party JSON and YAML packages all decode to plain tables or structs.
- Janet abstract types can supply `get`, `put` and `next`, so table-style access and iteration work. The type will not pass `table?` or `dictionary?`. That is intended: consumers that do not know the type fail loudly instead of dropping the order.
- spork stays unforked (D-ZBIADZDYXYPWLX5L). The JSON change goes in an overlay (D-DBGBXVNNTRBBRHMQ) that replaces `json/decode` and `json/encode`, and the unflagged path delegates to the upstream C functions.
- Natives may compile repo-owned C sources (D-FD4ZWTDKYJBQBFRO). Images must stay reproducible (L-2H7SFLEMCU2MPRZN, L-AGD7ZVHWYRGFIEDF).

### Origin
Promoted from backlog: B-JQKB2VOCY6XQW5V6 Ordered decode in the yaml module

## Now
BR agreed the name `omap` and the API sketch (2026-10-25). The ordered flag is a further optional positional after `nils`, matching spork/json's signature style. The build is delegated.

## Next
- The type comes first, then yaml, then the json overlay and its parity corpus, then dev-proc, then docs and CI.

## Evidence

## Harvest
- [ ] backlog: propose insertion-ordered tables to Janet upstream (#925), using chirp's type as the evidence
- [ ] backlog: ordered decode and encode for toml and jdn

## Log
- 2026-10-25 initialized from B-JQKB2VOCY6XQW5V6; BR picked an opaque ordered map type after a tech-debt comparison
- 2026-10-25 phase initialize → execute
