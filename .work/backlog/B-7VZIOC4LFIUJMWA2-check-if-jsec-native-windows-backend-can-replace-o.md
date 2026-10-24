---
created: 2026-10-24
---

# B-7VZIOC4LFIUJMWA2 Check if jsec native Windows backend can replace OpenSSL on Windows

## Why
If jsec's native Windows TLS backend is good enough, the Windows build could drop static OpenSSL. That would make it smaller, faster to build, and able to use the OS certificate store.

## Notes
Open question from the 2026-10-24 handoff. Relevant when the matrix widens to windows x64.
