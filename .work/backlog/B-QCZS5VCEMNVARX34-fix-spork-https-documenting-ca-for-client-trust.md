---
created: 2026-10-24
---

# B-QCZS5VCEMNVARX34 Fix spork-https documenting :ca for client trust

## Why
spork-https tells users to pass `:tls-opts {:ca …}`, which jsec ignores for clients (L-CPIUGJI6EY2HEID2), so custom trust silently does nothing.

## Notes
Report upstream, to spork-https (docs) or jsec (honour `:ca` on clients).
