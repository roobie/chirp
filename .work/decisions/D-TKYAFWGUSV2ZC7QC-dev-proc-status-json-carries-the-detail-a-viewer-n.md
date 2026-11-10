---
status: accepted
date: 2026-11-10
read_if:
  - changing the shape of dev-proc status --json
  - building a viewer or tool on dev-proc's JSON
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#record-json
  - .agents/skills/dev-proc/scripts/dev-proc.janet#unit-detail
---

# D-TKYAFWGUSV2ZC7QC dev-proc status --json carries the detail a viewer needs: per-unit and per-record by default, tree-wide behind --detail

## Context
dert shows dev-proc state for every checkout and may read it only through the CLI's JSON, decoded into unordered tables. The tree listing is read by dev-drive on every pass, so it has to stay small and its fields stable; a work dir can hold dozens of records whose sections are most of the bytes.

## Decision
`status <unit|record> --json` always gives the document's `sections` and a unit's Harvest items. The tree gives units `created` and `awaiting` and records their fields and problems, and gives every entry its sections only with `--detail`. `sections` is an array of `{heading, text}` in document order, because an object would lose the order and a repeated heading. Record fields are a fixed list: `created`, `date`, `status`, `priority`, `needs` come out as strings (a list is joined with ", ") and `refs`, `supersedes` as arrays (one string is a list of one); an unset or empty field is left out, and any other front matter key is not passed on. `awaiting` on a unit is a string the same way, so values dev-drive does not know still reach a viewer. Fields are added, never renamed or removed.

## Why
A board needs the owner-wait flags for every card, which one call gives; a page needs sections for one item, which one call gives. The tree-wide detail is opt-in so the default stays about a quarter of the size (chirp's own: 51 KB against 193 KB). One type per field lets a viewer decode without checking shapes. Rejected: sections always in the tree, which taxes every consumer for the viewer's sake; a second command for records; passing every front matter key, which would make the file format the JSON contract. Sections and Harvest reuse the parser `new --body` uses, and the finalize gate counts open items with the Harvest reader the JSON lists them with, so there is one reading of a document.

## Consequences
A viewer lists with the tree and fetches detail per item, or takes it all with `--detail`. A front matter field a record kind gains must be added to the lists in `record-fields` to show up.
