---
status: accepted
date: 2026-10-29
read_if:
  - changing chirp --help read --source or the serve source view
  - adding a bundled module or native
refs:
  - src/chirp/source.janet#locator
---

# D-ZWD5PKZDNQKXRE4M help bakes each binding's source at image build, located by source-map prefix rules held as data

## Context
While browsing `chirp --help serve`, BR wanted to see the definition behind a docstring. The help must work offline (D-6MHEZUS5HUJXWV6A), builds must be reproducible (D-Q23RA2EVVN5LYCX7), and no host path may be baked in. Every binding already records its file and line, and the build already has every source fetched.

## Decision
The source text of each documented binding, Janet forms and C function bodies alike, goes into the image at build time. The prefix rules in chirp.jdn that map a source-map file to a fetched source and to a display path are data. A binding no rule finds simply has no source.

## Why
BR chose to bake in both kinds of source, about 0.7MB on an 11MB binary, over linking to upstream on GitHub (which needs the network) or showing only `file:line`. Keeping the rules as data means a new module gets its source by adding a line to chirp.jdn, not by changing code. A C body is cut at the first line that is just `}`. That is a heuristic, but it holds for Janet core's style and chirp's own natives, and a C parser would be debt.

## Consequences
The binary grows with every bundled module that has a rule. A new module shows no source until it gets a rule. Source text is not searchable, and that would be a separate choice.
