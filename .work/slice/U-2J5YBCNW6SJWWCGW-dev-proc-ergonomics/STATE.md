---
phase: initialize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-30
success_criteria:
  - dates written by dev-proc follow the local calendar day, not UTC
  - new and record print just the id with --id, and a JSON object with --json
  - new takes --criterion (repeatable) and --purpose, and --execute passes the gate in the same call when owner and criteria are present
  - a trailers command prints the Work trailers for the staged .work/ changes, most specific first, and names a STATE.md the hook would require but is not staged
  - new and record take a body from --body-file or stdin, split into the template's sections by ## headings
  - one note command replaces Now or Next and appends to Evidence, Harvest or Log
  - each change has a smoke or unit test, and the bundled skill's SKILL.md documents it
---

# slice/dev-proc-ergonomics

## Purpose
Every unit and record the CLI creates needs a hand edit before it is usable, and agents assemble ids and trailers by hand. Closing that gap makes most units and records one command, while every change still shows in the diff. dev-proc now ships in the binary (`chirp --dev-proc --install`), so this friction reaches chirp's users too.

## Scope
In: chirp's dev-proc CLI (.agents/skills/dev-proc), its tests, and its SKILL.md.
Out: stale-ref rename hints (B-PC45JD26WTVBOKGI); a repo-config default owner; porting to spartan's Node copy (D-VZIDK5O2VNATQDCP; offered back afterwards).

## Context & constraints
- Source: ergonomics feedback from an agent's long session on the Node copy in another repo, triaged with BR on 2026-10-30.
- chirp's copy already has `new --owner a,b` and `status --json`.
- Reproduced here: at 00:50 local on 2026-10-30, `new` and `phase` wrote 2026-10-29; `today` uses UTC to match Node's `toISOString`.
- Lands after 0.5.0; does not block that release.

## Now
Not started.

## Next
- Order by cost: date fix → --id/--json → new fields + --execute → trailers → body input → note.

## Evidence

## Harvest
- [ ] process: the user-level dev-proc skill still says `node … dev-proc.mjs`, while this repo runs it with chirp; the agent tried node first

## Log
- 2026-10-30 initialized
