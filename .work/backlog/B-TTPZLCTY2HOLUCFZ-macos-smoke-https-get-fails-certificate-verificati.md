---
created: 2026-11-04
---

# B-TTPZLCTY2HOLUCFZ macOS smoke https-get fails certificate verification for example.com

## Why
Since 2026-11-04, smoke macos-arm64 fails https-get with "certificate verify failed" (runs 41893476794, 41893562405, 41898980038). main's macOS smoke was cancelled in the same period, so it was red there too, unseen. linux and windows pass the same check.

## Notes
- example.com now serves Cloudflare TLS Issuing ECC CA 3 → SSL.com TLS Transit ECC CA R2 → SSL.com TLS ECC Root CA 2022. Likely cause: that root is missing from the trust file chirp finds on the macOS runner (`/etc/ssl/cert.pem` in config.jdn's :ca-paths), which is not the keychain.
- First check which CA file chirp used there (`chirp -v` prints it), and whether that root is in it.
- Consider whether a smoke check should depend on one third-party host's CA chain at all; this is also the case for the embedded roots (D-B2RTYH6CNDO6SRF5).
