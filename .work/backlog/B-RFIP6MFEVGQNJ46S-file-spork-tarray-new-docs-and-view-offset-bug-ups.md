---
created: 2026-11-09
needs: owner
---

# B-RFIP6MFEVGQNJ46S File spork tarray/new docs and view-offset bug upstream; drop the tarray overlay when fixed

## Why
chirp documents `tarray/new` through `src/chirp/overlay-spork-tarray.janet` because spork does not (#9), and spork computes a wrong start for a typed array over a view that is not at byte 0. BR files this upstream; once spork documents `tarray/new`, delete the overlay and its `:overlays` entry, and once the start is fixed, drop that paragraph of the docstring.

## Notes
Draft for janet-lang/spork:

> Title: tarray/new: document its arguments; offset is wrong over a view that does not start at byte 0
> 
> **1. Docs.** `(doc tarray/new)` says only "Create new typed array." It does not say:
> 
> - `offset` counts bytes when the last argument is a buffer, string or ta/buffer, but elements of the parent's type when it is a typed array, while `size` and `stride` count elements.
> - A buffer or string is copied (`memcpy` in `cfun_typed_array_new`), so the array does not see later changes and writes do not reach it; a ta/buffer or typed array is shared.
> - Numbers are in the host's byte order.
> 
> Reading fields from a slurped binary header took trial and error to find that the offset is in bytes (reported downstream in roobie/chirp#9).
> 
> **2. Bug.** Over a typed array that does not start at its buffer's first byte, the start is computed with the sign reversed:
> 
> ```janet
> (import spork/tarray)
> (def b @"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b")
> (def v (tarray/new :uint8 8 1 4 b))   # starts at byte 4
> (tarray/new :uint8 2 1 1 v)
> # error: bad buffer size, 12 bytes allocated < -1 required
> ```
> 
> In `cfun_typed_array_new`:
> 
> ```c
> offset = (view->buffer->data - view->as.u8) + offset * ta_type_sizes[view->type];
> ```
> 
> `view->as.u8` points `view`'s offset bytes past `buffer->data`, so this subtracts the parent's offset instead of adding it. `(view->as.u8 - view->buffer->data)` looks like what was meant. The expected result above is a view of bytes 5 and 6.
> 
> Seen on spork master (src/tarray.c unchanged since the version chirp pins), Janet 1.43.0, linux x64.
