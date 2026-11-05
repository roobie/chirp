---
date: 2026-11-05
read_if:
  - a TLS check passes on roots chirp did not choose
  - testing which trust store chirp uses
refs:
  - tools/build/config.jdn
---

# L-OO7ZGOBI22DEUO5R chirp's OpenSSL still reads /etc/ssl on every target, because openssldir is /etc/ssl

## Observation
tools/build/config.jdn configures OpenSSL with `--openssldir=/etc/ssl` for every target. So whenever SSL_CERT_FILE and SSL_CERT_DIR are unset, chirp's OpenSSL reads `/etc/ssl/cert.pem` and `/etc/ssl/certs` on every OS, macOS and windows included. When SSL_CERT_FILE is set, the hash dir `/etc/ssl/certs` is still consulted.

## Why it matters
A test that trusts a host can pass on roots that don't come from the store chirp names. Under Wine, `/etc/ssl` reaches the container's real store, which probably explains B-IOPVTTA3XW3OKYXQ. To prove which trust a check uses, run in a container with no `/etc/ssl`, such as busybox: there chirp says `none found` and https-get fails verification.
