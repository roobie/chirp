---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-08
success_criteria:
  - A tasks help topic has one section per goal, each with the import and a short example; chirp -h's usage points at it
  - The build fails when a bundled module (chirp.jdn :modules) is not named in the topic
  - A smoke check runs every janet example in the topic and requires exit 0, on each native runner
  - 'chirp --help query for the goals of #4 (print a table), #6 (validate data) and #8 (json) lists the topic''s section first'
---

# slice/help-by-goal

## Purpose
Users arrive with a goal, not a module name (#4, #6, #8). A help topic indexed by goal names the module and shows a runnable example, and --help query finds it from the user's words.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-YHAOKYFCK6MVRMXE Surface bundled functionality by end-goal in the help

### Why
#4 (a table formatter), #6 (parse-don't-validate) and #8 (`(import json)`) are all discoverability failures. chirp already bundles `spork/misc` `print-table` and `spork/schema`, and JSON is `spork/json`, but the help is organised by module, and a user arrives with a goal ("print a table", "validate this input", "read JSON"), not a module name. `chirp --help query` searches the module docs, so a goal phrased in the user's words often misses, or ranks a changelog entry first (#8). BR, 2026-11-08: surface the functionality by end-goal.

### Notes
- Shape to weigh: one help topic indexed by goal (say `tasks`), where each entry is a goal in plain words, the import line, and a two-to-five-line example. It is listed first under Topics in `chirp -h`, and `chirp --help query` ranks it above changelog entries for the same words. A goal with nothing bundled says so, and says what to use instead, so a miss is an answer too.
- Cover every bundled module and chirp's own (json, yaml, toml, sqlite, https, gzip, tar, zip, pcre2, lexbor, md4c, omap, schema, misc print-table, path, sh, argparse and the rest), plus the common goals with no module yet: CSV (B-3U2LXKLBUDLJGUOO), XML (B-U4PHFF5M2IYP4GRX), fast hashing (B-3SL5UBKVU5LIEA5F).
- Keep it from drifting: a build-time or smoke check that every module bundled per src/chirp/chirp.jdn is named in the topic, so adding a module without a goal entry fails. Examples should run, as the help smoke check already does for snippets.
- The query side may need synonyms or a heavier weight for this topic's titles in the bm25 ranking (src/chirp/help.janet), since goal words ("table", "validate") are not module words.
- #8's import hint for short names stays its own item (B-S3NXI7Y7RE7GGQPI); this topic is where that hint can point.
- Done when the goals from #4, #6 and #8, typed into `chirp --help query`, put this topic's entry first, and those issues are answered with a link to it.
- The gaps a goal entry should state honestly (from B-LXVEZMLKF5VJOQZQ, folded in here): `print-table` has no alignment, number formatting or output formats (markdown, grid) like tabulate's; `spork/schema` validates (`validator`, `predicate`) but does not coerce or build typed results. A gap that matters becomes its own item, preferably as an upstream spork change rather than a chirp-owned module.


## Now
Pushing for CI on all four targets.

## Next
Finalize once CI is green; answer #4, #6 and #8 with a link to the tasks topic (BR).

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Build guard: before the check accepted `name/` mentions, the linux-x64 build failed with 'help/tasks.md names no goal for spork/argparse, spork/data, spork/misc, spork/stream'.
- Local linux-x64 build: smoke run passes, tasks check runs 28 examples; help check asserts 'print a table', 'validate data', 'json', 'import json' list the tasks section first; site builds with help/tasks.html and site/check passes.
- Boost 2 put tasks above the sqlite topic for 'sqlite'; 1.5 keeps topics that match better first (sqlite, tar) while goal words still land on tasks (json, validate, regex, date, csv, hash).
- CI 42530993983 (7255c4e): all builds and compare pass; smoke windows-x64 failed the tasks check: 'Run another program' used spork/sh/self-exe, which returned nil there. The example now runs (dyn *executable*).

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: help is indexed by goal in one topic that must name every bundled module, and its entries carry a 1.5 relevance boost rather than synonyms or a separate index
- [ ] process: c9f7175 changed --version output without searching for its consumers (ca-roots smoke, pages.yml); CI went red after push and I did not watch it
- [ ] learning: spork/sh/self-exe returned nil on the windows runner for chirp run by an absolute path (abspath? false, then which fails); use (dyn *executable*)

## Log
- 2026-11-08 initialized
- 2026-11-08 phase initialize → execute
- 2026-11-08 CI windows smoke caught a non-portable example; fixed
