---
created: 2026-10-28
---

# B-VDJWHBDAHVSYULLB Integration tests for the Pages site with lexbor

## Why
The site build checks only links, by matching text. BR wants structural checks on the generated site and on the live site after each deploy, which was the first use named for bundling an HTML parser (D-AYM6G4PAISONUDLK).

## Notes
- On `out/site`: every page has the nav, ids are unique per page, every relative `a[href]` resolves to a page or an id.
- On https://roobie.github.io/chirp/ after the `pages` workflow deploys, over spork-https: the same checks, plus the footer's version matching the release.
- A quick try while building lexbor already showed `out/site` pages and the live index parse and select as expected.
