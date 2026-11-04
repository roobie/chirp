---
status: accepted
date: 2026-11-04
read_if:
  - changing dev-proc report or dig
  - adding a dev-proc view over history
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#cmd-report
  - .agents/skills/dev-proc/scripts/dev-proc.janet#work-path
---

# D-P4UALB3TXI4BV5UM dev-proc report reads only git and defaults to the last tag

## Context
BR wanted a short overview of the dev-proc work done over a stretch of history, e.g. what a session or a release held. status shows only the present, and dig follows one id.

## Decision
`report` derives everything from git: a unit starts when its STATE.md is added and closes when it is deleted, and a `Decision:` trailer on the closing commit makes it a scrap. Commit counts come from `Work:` trailers, and labels and parents from the unit's last STATE.md as of the range's end. With no range it covers the last tag to HEAD. dig and report recognise paths through one shared reader.

## Why
History already holds all of it, so a stored log would be a second copy that could disagree with git. The last tag matches how chirp is released, so a bare `report` answers "what has happened since the release". Reading the last STATE.md as of the range's end, not as of today, labels a unit by its name at that time. One path reader stops dig and report from drifting apart, the risk raised when report was discussed.

## Consequences
Uncommitted work never shows; status covers it. Trailers that name units with no files in history (ids from before the port) show without a label. Out-of-band roots are not reported.
