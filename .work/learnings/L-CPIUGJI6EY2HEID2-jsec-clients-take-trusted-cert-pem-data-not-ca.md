---
date: 2026-10-24
read_if:
  - configuring TLS client trust
  - using spork-https :tls-opts
refs:
  - test/spike/https-server.janet
---

# L-CPIUGJI6EY2HEID2 jsec clients take :trusted-cert PEM data, not :ca

## Observation
jsec's client connect ignores `:ca`. Client trust is set with `:trusted-cert`, which takes PEM data, not a path. spork-https documents `:tls-opts {:ca …}`, which silently leaves trust unchanged.

## Why it matters
A wrong option fails open into the default trust store, not with an error, so a test that "passes" may not be testing the trust you meant. Matters for the CA-root work (D-B2RTYH6CNDO6SRF5). Stops applying if jsec starts honouring `:ca` (B-QCZS5VCEMNVARX34).
