---
created: 2026-10-25
---

# B-EQDYP6GUADPM3NPT Ordered decode and encode for toml and jdn

## Why
Config files in TOML or JDN have the same problem JSON and YAML had: a script that rewrites one loses the author's key order.

## Notes
tomlin is written in Janet and would need an overlay; jdn goes through Janet's own parser and printer. Wait for a script that needs it.
