---
date: 2026-11-05
read_if:
  - calling Apple frameworks through dlopen
  - the macOS keychain export finds nothing
refs:
  - src/osroots/osroots.c
---

# L-2UJPBNW7I6UK3CM4 SecTrustSettings keys are CFSTR literals, not symbols Security.framework exports

## Observation
`kSecTrustSettingsResult`, `kSecTrustSettingsPolicy` and the other keys in SecTrustSettings.h are `CFSTR("...")` macros, so Security.framework exports no symbol for them and dlsym returns NULL. Keys declared `extern const CFStringRef`, such as `kSecPolicyOid` and `kSecPolicyAppleSSL`, are exported and dlsym finds them. osroots creates the macro keys with CFStringCreateWithCString.

## Why it matters
Without an SDK, the header is the only place that says which kind a key is, and a wrong guess fails silently: the first macOS CI run exported no roots and chirp said `none found`. Check each key in the header before reaching it through dlsym, and make a failed lookup name itself.
