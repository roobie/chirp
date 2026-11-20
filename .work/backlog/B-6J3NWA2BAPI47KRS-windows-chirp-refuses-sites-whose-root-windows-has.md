---
created: 2026-11-20
---

# B-6J3NWA2BAPI47KRS windows chirp refuses sites whose root Windows has not fetched yet

## Why
A windows chirp trusts only the roots already in the Windows store, but Windows downloads a root from Windows Update only when its own chain building first needs it. On a machine where no Schannel program has met a site's root, chirp refuses that site with `certificate verify failed`, while every Windows program accepts it. The CI runner image ships with every root fetched (417 against 77 on a working machine), so CI never shows it.

## Notes
Seen on real windows on 2026-11-20, with 0.12.0 and 0.13.0-dev alike: `https-get` to example.com failed with 77 roots exported. Its root (SSL.com TLS ECC Root CA 2022) was not in the store until a PowerShell `SslStream` handshake made Windows fetch it into `LocalMachine\AuthRoot`; the next export held 78 roots and `https-get` passed. The export's own filters (Disallowed, server-auth EKU) keep that root, so they are not the cause.

Options weighed at the time:
- Windows verifies the default-trust chain (`CertGetCertificateChain` plus `CertVerifyCertificateChainPolicy` with the SSL policy), through a verify hook in jsec. It matches what Windows trusts, fetches missing roots, and drops the export on windows. An explicit `:ca` or `:trusted-cert` stays OpenSSL-only. Preferred.
- Fetch the chain through Windows on failure, export again and retry: a second handshake and a retry in every client path, and it still loses per-root limits.
- Sync Microsoft's whole root list at export: copies Windows Update and overrides admins who turned automatic root updates off.
- Bundle roots as a fallback: against trusting only the OS.

A test needs a runner with a root removed from `AuthRoot`; Wine cannot show this. Related: task windows-ca-root-source (U-QARLWBBV3ZM6QQU7), which asks what else windows chirp trusts.
