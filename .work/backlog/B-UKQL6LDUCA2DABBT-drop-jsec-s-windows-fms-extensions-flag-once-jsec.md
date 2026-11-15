---
created: 2026-11-15
---

# B-UKQL6LDUCA2DABBT Drop jsec's windows -fms-extensions flag once jsec uses JANET_THREAD_LOCAL throughout

## Why
chirp passes `-fms-extensions` to jsec on windows (tools/build/config.jdn `:pin-cflags`) only so zig clang honours `__declspec(thread)` (L-MMOQJTXSQIJQ4CCS). A compiler flag that exists for one dep's spelling is a cost at every zig or jsec bump, and `JANET_THREAD_LOCAL` needs no flag (L-HQU7QUZ7G2TGDB6H).

## Notes
- jsec ticket 4e62dc7283 moved `src/jutils/error.c` to `JANET_THREAD_LOCAL`, but the pin (9b57288) still has two `static __declspec(thread)` buffers in `src/compat.h` (lines 209 and 218), so the flag is still needed.
- An upstream ask would be a fossil ticket (https://code.amlegion.org/jsec/): use `JANET_THREAD_LOCAL` in `src/compat.h` as 4e62dc7283 did in error.c.
- Once the pin has no `__declspec(thread)`, drop the flag, confirm with `objdump -h` that the buffers still land in `.tls$`, and update or remove L-MMOQJTXSQIJQ4CCS.
