---
created: 2026-10-24
---

# B-QCZS5VCEMNVARX34 Fix spork-https documenting :ca for client trust

## Why
spork-https tells users to pass `:tls-opts {:ca …}` for clients, which jsec's `tls/connect` ignores (L-CPIUGJI6EY2HEID2). A script that meant to trust only its own CA then trusts the whole system store instead.

## Notes
Smallest repro: about 15 lines of plain jsec. Start `tls/server` on localhost with a self-signed cert written to `ca.pem`, then connect three ways with verification on. `{:trusted-cert pem}` and `{:security {:ca-file "ca.pem"}}` connect; `{:ca "ca.pem"}` fails with `certificate verify failed`. Report it to spork-https (fix the docs to `:security {:ca-file …}`) and to jsec (either read `:ca` on clients, as servers and `new-context` already do, or reject unknown keys).
