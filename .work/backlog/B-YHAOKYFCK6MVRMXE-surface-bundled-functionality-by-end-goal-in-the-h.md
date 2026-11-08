---
created: 2026-11-08
---

# B-YHAOKYFCK6MVRMXE Surface bundled functionality by end-goal in the help

## Why
#4 (a table formatter), #6 (parse-don't-validate) and #8 (`(import json)`) are all discoverability failures. chirp already bundles `spork/misc` `print-table` and `spork/schema`, and JSON is `spork/json`, but the help is organised by module, and a user arrives with a goal ("print a table", "validate this input", "read JSON"), not a module name. `chirp --help query` searches the module docs, so a goal phrased in the user's words often misses, or ranks a changelog entry first (#8). BR, 2026-11-08: surface the functionality by end-goal.

## Notes
- Shape to weigh: one help topic indexed by goal (say `tasks`), where each entry is a goal in plain words, the import line, and a two-to-five-line example. It is listed first under Topics in `chirp -h`, and `chirp --help query` ranks it above changelog entries for the same words. A goal with nothing bundled says so, and says what to use instead, so a miss is an answer too.
- Cover every bundled module and chirp's own (json, yaml, toml, sqlite, https, gzip, tar, zip, pcre2, lexbor, md4c, omap, schema, misc print-table, path, sh, argparse and the rest), plus the common goals with no module yet: CSV (B-3U2LXKLBUDLJGUOO), XML (B-U4PHFF5M2IYP4GRX), fast hashing (B-3SL5UBKVU5LIEA5F).
- Keep it from drifting: a build-time or smoke check that every module bundled per src/chirp/chirp.jdn is named in the topic, so adding a module without a goal entry fails. Examples should run, as the help smoke check already does for snippets.
- The query side may need synonyms or a heavier weight for this topic's titles in the bm25 ranking (src/chirp/help.janet), since goal words ("table", "validate") are not module words.
- #8's import hint for short names stays its own item (B-S3NXI7Y7RE7GGQPI); this topic is where that hint can point.
- Done when the goals from #4, #6 and #8, typed into `chirp --help query`, put this topic's entry first, and those issues are answered with a link to it.
- The gaps a goal entry should state honestly (from B-LXVEZMLKF5VJOQZQ, folded in here): `print-table` has no alignment, number formatting or output formats (markdown, grid) like tabulate's; `spork/schema` validates (`validator`, `predicate`) but does not coerce or build typed results. A gap that matters becomes its own item, preferably as an upstream spork change rather than a chirp-owned module.
