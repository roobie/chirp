---
created: 2026-10-24
---

# B-IOPVTTA3XW3OKYXQ Find where chirp on windows finds CA roots when SSL_CERT_FILE is empty

## Why
Under Wine, an HTTPS GET to a public site still succeeded with `SSL_CERT_FILE` pointing at an empty file, so trust comes from somewhere we did not choose. Until we know where, we cannot say which roots a windows chirp trusts, and the embedded-roots work (D-B2RTYH6CNDO6SRF5) cannot claim to replace that source.

## Notes
Verification itself is on: a self-signed certificate is rejected with `certificate verify failed`. Suspects are jsec's CA path probing and OpenSSL's compiled-in `--openssldir=/etc/ssl`, which Wine maps to the container's real `/etc/ssl`. Check on real windows too.
