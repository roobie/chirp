---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-05
success_criteria:
  - 'macOS chirp trusts the roots its keychain trusts: smoke https-get example.com passes on macos-15'
  - 'windows chirp needs no SSL_CERT_FILE: CI sets none and https-get passes'
  - 'chirp -v names the source: a bundle path, or the OS store and the file it was exported to'
  - with no OS trust found, chirp reports none found and verification fails; no trust ships in the binary
  - all four targets build twice with matching sha256 and every smoke check passes
---

# slice/os-trust-stores

## Purpose
chirp's TLS trusts what the OS trusts on every target, and nothing chirp itself ships: system bundle files on Linux and the BSDs, the keychain's trust settings on macOS, the ROOT store on windows. BR rejected embedded roots (no trust bundled in the binary), so D-B2RTYH6CNDO6SRF5's embedded fallback goes.

## Scope
In: a chirp-owned native that exports the OS's trusted roots (keychain trust settings on macOS, ROOT minus Disallowed on windows); per-OS CA probing; chirp -v reporting; docs; dropping the hand-set windows SSL_CERT_FILE in CI and the Wine smoke; a ca-roots smoke check.
Out: handing verification itself to the OS (partial distrusts, revocation): backlog. The windows trust-source question (B-IOPVTTA3XW3OKYXQ) beyond what this shows.

## Context & constraints
- No trust anchors in the binary (BR, 2026-11-04): no embedded bundle, no pinned bundle hash.
- SSL_CERT_FILE stays the user's override.
- jsec takes default trust only through OpenSSL's SSL_CERT_FILE (six SSL_CTX_set_default_verify_paths sites across four jutils copies), so exported roots reach it as a file.
- No Apple SDK in the cross build (L-ARS76O3UDJQ2JZQB): Security.framework is reached with dlopen and prototypes chirp declares.
- Host-dependent values are computed at run time (L-J2G76CUIQU4OWGMK); native function names carry a prefix (L-BVXC557ZOWPP4SN5).
- Reusable from the rejected attempt (/tmp/embedded.patch locally, and git objects 8f4e239): per-OS :ca-paths, cache-file writing, -v reporting, the ca-roots smoke check, the CI and Wine SSL_CERT_FILE removals.

### Origin
Promoted from backlog: B-TTPZLCTY2HOLUCFZ macOS smoke https-get fails certificate verification for example.com

### Why
Since 2026-11-04, smoke macos-arm64 fails https-get with "certificate verify failed" (runs 41893476794, 41893562405, 41898980038). main's macOS smoke was cancelled in the same period, so it was red there too, unseen. linux and windows pass the same check.

### Notes
- example.com now serves Cloudflare TLS Issuing ECC CA 3 → SSL.com TLS Transit ECC CA R2 → SSL.com TLS ECC Root CA 2022. Likely cause: that root is missing from the trust file chirp finds on the macOS runner (`/etc/ssl/cert.pem` in config.jdn's :ca-paths), which is not the keychain.
- First check which CA file chirp used there (`chirp -v` prints it), and whether that root is in it.
- Consider whether a smoke check should depend on one third-party host's CA chain at all; this is also the case for the embedded roots (D-B2RTYH6CNDO6SRF5).


## Now
Fixed: kSecTrustSettingsResult/Policy are CFSTR literals in SecTrustSettings.h, not exported symbols, so the dlsym failed silently; they are now made with CFStringCreateWithCString. Failures now name what failed (chirp -v shows none found (why)). CI rerun pending.

## Next
- CI: macOS ca-roots must report the keychain with many roots, https-get must pass; note the startup cost the export adds on macOS
- if the macOS export is slow, decide whether to keep it per start or reuse a recent export
- finalize: decision (supersedes D-B2RTYH6CNDO6SRF5), learning, backlog for the OS verifier

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Cause confirmed (diag run 41919522154, macOS 15.8.2): /etc/ssl/cert.pem holds 126 certs and neither SSL.com TLS ECC Root CA 2022 nor AAA Certificate Services, which example.com chains to; the system keychain holds the root, and curl gets 200.
- Local builds of linux-x64, macos-arm64 and windows-x64 compile osroots cleanly. linux: ca-roots reports the system bundle, chirp -v 11 ms; in busybox with no /etc/ssl, chirp -v says none found and https-get fails verification (no trust in the binary). Wine: ca-roots exports 84 roots from the windows store to %LOCALAPPDATA%/chirp/os-roots.pem, https-get 200 with no SSL_CERT_FILE; chirp -v 174 ms under Wine. dev-proc-install fails under Wine only because the ad-hoc run mounts test/smoke alone.
- CI run 41935128855 on 30b1d87: windows smoke green with no SSL_CERT_FILE (417 roots from the store, chirp -v 55 ms, https-get 200); all double builds identical. macOS: none found, silently: the export returned nil.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: no CA trust ships in the binary; chirp uses the OS stores and fails loudly without them (supersedes D-B2RTYH6CNDO6SRF5)
- [ ] learning: chirp's OpenSSL is built with --openssldir=/etc/ssl, so it reads /etc/ssl/cert.pem and /etc/ssl/certs on every target unless told otherwise; likely B-IOPVTTA3XW3OKYXQ's source under Wine
- [ ] backlog: hand verification to the OS verifier (SecTrust, CertGetCertificateChain) for partial distrusts and revocation

## Log
- 2026-11-05 initialized
- 2026-11-05 phase initialize → execute
- 2026-11-05 embedded-roots attempt (branch embedded-ca-roots, CI run 41922503414 green) rejected by BR: trust must not be bundled in the binary; fetching a bundle at run time has no trust anchor but the OS, so read the OS stores directly
