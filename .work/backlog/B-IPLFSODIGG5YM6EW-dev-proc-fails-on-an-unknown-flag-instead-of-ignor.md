---
created: 2026-11-11
---

# B-IPLFSODIGG5YM6EW dev-proc fails on an unknown flag instead of ignoring it

## Why
`parse-args` in .agents/skills/dev-proc/scripts/dev-proc.janet takes any `--key value` pair and no command checks the keys it was given. So a mistyped or made-up flag is silently dropped and the command succeeds. In a skelly drive session, `record … --section "Why=…"` (a flag that does not exist; the real ones are `--body` and `--body-file`) created about 20 decisions, learnings and backlog items whose sections held only TODO placeholders. Nothing warned, and the lost text had to be recovered from the session transcript. An agent working from memory will invent plausible flags, so an unknown flag must be an error that names the valid ones, the way an unknown heading already is.

## Notes
- Each command already knows its options from HELP. One table of the flags each command accepts, checked in `parse-args` or in the dispatch, would cover them all.
- A test should run one command with an unknown flag and expect a non-zero exit, with stderr naming the flag.
- This is related to B-HFEHNNAUWFDXTAMQ (Janet's cli-main exits 0 on an unknown flag), but this gap is dev-proc's own parser and is fixable here.
