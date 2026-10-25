---
created: 2026-10-25
---

# B-NEQ4LIZJMAZOYQLA GitHub Pages site for chirp

## Why
A reader deciding whether to use chirp should not have to read a GitHub repo first. A small site shows what chirp is, what it bundles, and how to install it. It can also put the offline help topics online, where a search engine finds them.

## Notes
- Tone (BR): no-nonsense, down-to-earth, informational and terse. No marketing voice.
- Build the pages from what already exists (README, `src/chirp/help/*.md`, CHANGELOG.md), so the site cannot drift from the binary's own docs. Generate them with chirp itself rather than with a Node or Ruby site generator.
- Publish from CI on release tags, so the site describes the latest release, not main.
- Set the site URL as the repo's homepage; that needs a token with the Administration permission, which the current one lacks.
