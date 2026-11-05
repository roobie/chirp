---
status: accepted
date: 2026-11-05
read_if:
  - TLS certificate verification fails
  - changing where chirp looks for CA roots
  - considering an embedded or downloaded CA bundle
refs:
  - src/chirp/ca.janet#setup
  - src/chirp/ca.janet#from-store
  - src/osroots/osroots.c
  - src/chirp/chirp.jdn#ca-paths
supersedes:
  - D-B2RTYH6CNDO6SRF5
---

# D-DGT7DONSVJESO5FV CA trust comes only from the OS; chirp ships none and fails loudly without it

## Context
D-B2RTYH6CNDO6SRF5 said to probe the system CA paths and fall back to a CA bundle embedded in the binary. On macOS the probe found `/etc/ssl/cert.pem`, a snapshot the OS does not keep current: it lacks the SSL.com root example.com moved to, so chirp rejected a site curl accepted. Windows has no bundle file, so users set SSL_CERT_FILE by hand. A slice that embedded Mozilla's roots (pinned from curl) worked, and BR rejected it.

## Decision
chirp ships no trust anchors: no CA bundle, and no hash or key that vouches for one. SSL_CERT_FILE wins when set. Otherwise trust comes from the OS: the system bundle file on Linux and the BSDs, the roots the keychain's trust settings accept for TLS on macOS, and the ROOT store minus Disallowed on windows. With none of these, chirp -v says `none found` and verification fails.

## Why
- **An embedded bundle:** rejected. It freezes trust at build time, so a Mozilla distrust (TrustCor, Entrust) reaches users only when someone bumps a pin and they update. It also ignores the CAs an organisation installs and the distrusts an admin sets, and it is a pin to keep up forever.
- **Downloading a bundle at run time:** its integrity needs an anchor. An embedded hash or key is embedded trust again, a sha256 fetched from the same place proves nothing, and anything else is trust on first use. The only sound anchor left is the OS, and then the OS store can be read directly.
- The OS store is what the user and their admin manage and what the OS updates, so chirp agrees with curl, browsers and every other native client.

## Consequences
- macOS and windows need a native that reads their stores (`osroots`). It opens Security.framework at run time, since the cross build has no Apple SDK.
- Trust is exported as roots only. Partial distrusts (a root distrusted for certificates issued after a date) and revocation are not carried over; B-CJNYKLBSXESBPAQY.
- A minimal Linux host without a CA bundle gets no HTTPS until SSL_CERT_FILE names one. That is deliberate.
