---
date: 2026-11-14
read_if:
  - configuring TLS client trust
  - using spork-https :tls-opts
  - bumping the jsec pin
refs:
  - test/smoke/https-server.janet#ca-only
  - src/chirp/help/https.md
---

# L-3ESBZZEAYDWS4KNQ jsec clients trust only :ca, while :trusted-cert and :security {:ca-file} add to the system store

## Observation
From jsec's 0.2.0 series, a client's `:ca` (a path or PEM) is the only trust anchor of that connection: the system store no longer applies. `:trusted-cert` and `:security {:ca-file …}` still add to the system store. Older jsec ignored a client `:ca`, which is why chirp's spork-https overlay used to map it onto `:ca-file` (llmII/jsec#1).

## Why it matters
The two ways to name a CA now mean opposite things. A script that wants to trust only its own CA must use `:ca`; one that uses `:ca-file` also accepts any publicly trusted cert, silently. A check of the exclusive case needs the other server to be trusted some other way (the system store), or a refusal proves nothing.
