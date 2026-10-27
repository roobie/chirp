---
phase: initialize
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-27
success_criteria:
  - 'TODO: observable outcome that proves this unit is done'
---

# slice/gh-pages-site

## Purpose
A public site that says what chirp is and how to get it, and documents the way this repo is run (dev-proc), so neither needs a reader to dig through the repo.

## Scope
In: a chirp script that generates the site from the repo's own Markdown; pages for chirp (README, help topics, changelog) and for dev-proc; a Pages deploy workflow.
Out: a custom domain; search; versioned docs.

## Context & constraints
- Blocked on slice/md4c (U-XHNWANHLCDSBMPPJ): the generator renders with `md4c/to-html` (BR, 2026-10-27).
- Open with BR: dev-proc section's source (a human intro plus SKILL.md as-is, SKILL.md alone, or new docs).
- Pages must be set to deploy from GitHub Actions in the repo settings, which needs an admin.

### Origin
Promoted from backlog: B-NEQ4LIZJMAZOYQLA GitHub Pages site for chirp

### Why
A reader deciding whether to use chirp should not have to read a GitHub repo first. A small site shows what chirp is, what it bundles, and how to install it. It can also put the offline help topics online, where a search engine finds them.

### Notes
- Tone (BR): no-nonsense, down-to-earth, informational and terse. No marketing voice.
- Build the pages from what already exists (README, `src/chirp/help/*.md`, CHANGELOG.md), so the site cannot drift from the binary's own docs. Generate them with chirp itself rather than with a Node or Ruby site generator.
- Publish from CI on release tags, so the site describes the latest release, not main.
- Set the site URL as the repo's homepage; that needs a token with the Administration permission, which the current one lacks.


## Now
Waiting on slice/md4c.

## Next
- Settle the dev-proc content source with BR, then write success criteria and DESIGN.md.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-10-27 initialized
