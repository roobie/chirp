---
created: 2026-11-05
---

# B-CJNYKLBSXESBPAQY Hand TLS verification to the OS verifier on macOS and windows

## Why
chirp exports the OS store's roots and lets OpenSSL verify against them (D-DGT7DONSVJESO5FV). That loses what the OS verifier knows beyond a root list: partial distrusts (Apple and Microsoft distrust some roots only for certificates issued after a date), constrained or EKU-limited roots, intermediates the OS fetches, and revocation. A user on macOS or windows can get a different answer from chirp than from their browser.

## Notes
- Hand the chain to SecTrustEvaluateWithError (macOS, via dlopen as osroots does) or CertGetCertificateChain plus CertVerifyCertificateChainPolicy (windows) from a jsec verify callback. That is a jsec patch or upstream change, since jsec owns the SSL_CTX.
- The root export would then only serve OpenSSL users outside jsec, or could go.
