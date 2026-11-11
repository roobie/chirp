---
created: 2026-10-24
needs: owner
---

# B-IOPVTTA3XW3OKYXQ Find where chirp on windows finds CA roots when SSL_CERT_FILE is empty

## Why
Under Wine, an HTTPS GET to a public site still succeeded with `SSL_CERT_FILE` pointing at an empty file, so trust comes from somewhere we did not choose. Until we know where, we cannot say which roots a windows chirp trusts, and we cannot say the OS store chirp exports (D-DGT7DONSVJESO5FV) is the only source.

## Notes
Verification itself is on: a self-signed certificate is rejected with `certificate verify failed`. Suspects are jsec's CA path probing and OpenSSL's compiled-in `--openssldir=/etc/ssl`, which Wine maps to the container's real `/etc/ssl`. Check on real windows too.
- 2026-11-05: windows chirp now exports the ROOT store and real windows CI passes https-get without a hand-set bundle. The likely extra source is still OpenSSL's `--openssldir=/etc/ssl` hash dir, which Wine maps to the container's store (L-OO7ZGOBI22DEUO5R); unconfirmed on real windows.
