---
status: accepted
date: 2026-11-05
read_if:
  - changing how OS trust reaches jsec
  - chirp writes to the user cache directory
  - chirp start-up time
refs:
  - src/chirp/ca.janet#export
  - src/chirp/main.janet#defer-tls-modules
---

# D-3IC4LK7ZRJETEVVU The OS store reaches OpenSSL as an export file in the user cache dir, written when TLS is first needed

## Context
jsec loads default trust with SSL_CTX_set_default_verify_paths at six call sites across four copies of jutils, and OpenSSL's default trust has no in-memory form: it reads SSL_CERT_FILE, a hash dir, or a store URI with no default. Reading the macOS keychain takes 170-290 ms (CI, macos-15), and a chirp start without it takes about 15 ms.

## Decision
On macOS and windows chirp writes the roots the OS trusts to `chirp/os-roots.pem` in the per-user cache directory, through a temporary file and a rename and only when the bytes differ, and points SSL_CERT_FILE at it. This happens the first time a jsec or spork-https module is required (they are left out of module/cache and found through a module/paths loader), and eagerly for chirp -v, the repl banner and --self-update. A chirp that inherits SSL_CERT_FILE naming the export does not redo it.

## Why
- **A jsec patch taking a process-wide PEM:** a third carried patch over six call sites and four jutils copies, carried at every pin bump until upstream took it.
- **The file** reaches every TLS user the same way: the overlay, the update module, scripts calling jsec directly, and child processes that use OpenSSL.
- **Exporting at every start:** a quarter of a second on every macOS chirp invocation, TLS or not.
- **Reusing an export younger than N minutes:** cheap, but a root the user distrusts or adds takes up to N minutes to apply.
- A shared temp directory is not used, because another user could plant the file there.

## Consequences
- A bundled module that captured jsec at image build (update.janet) does not go through the loader, so its entry point must export first. A new one must too.
- A chirp started by a script that never used TLS sees SSL_CERT_FILE unset, and exports itself if it needs TLS.
- A host with no writable cache directory gets `none found (...)` on macOS and windows; SSL_CERT_FILE is the way out.
- If jsec later accepts a default trust PEM or store, the file can go.
