---
date: 2026-10-24
read_if:
  - configuring TLS client trust
  - using spork-https :tls-opts
refs:
  - test/smoke/https-server.janet
---

# L-CPIUGJI6EY2HEID2 jsec clients take :trusted-cert or :security {:ca-file}, not :ca

## Observation
`tls/connect` ignores a top-level `:ca`. Only the server, `new-context` and DTLS paths read it. Client trust is set with `:trusted-cert` (PEM data) or `:security {:ca-file …}` (a path or PEM), which matches jsec's own API docs. spork-https documents `:tls-opts {:ca …}` for clients, and that is the part that is wrong.

## Why it matters
An ignored `:ca` falls back to the system trust store. A private CA is then rejected, which is safe and loud. But a script that meant to trust *only* its own CA also accepts any publicly trusted cert, which is silent. Use `:security {:ca-file …}` for the CA-root work (D-B2RTYH6CNDO6SRF5). This stops applying if jsec starts reading `:ca` on clients (B-QCZS5VCEMNVARX34).
