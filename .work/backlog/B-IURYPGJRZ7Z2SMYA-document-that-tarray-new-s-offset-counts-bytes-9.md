---
created: 2026-11-04
---

# B-IURYPGJRZ7Z2SMYA Document that tarray/new's offset counts bytes (#9)

## Why
GitHub #9 (usage-feedback): `(doc tarray/new)` says only "Create new typed array." and does not say that `offset` counts bytes while size and stride count elements, or that a plain buffer (from `slurp`, say) works as the backing store. Parsing a binary header took trial and error.

## Notes
- The docstring is spork's (src/tarray.c), and chirp does not patch docs into pins, so the docstring fix belongs upstream at janet-lang/spork; the repo's token cannot file there, so BR files it.
- chirp can help on its own side with a help topic (src/chirp/help/) on reading binary data: tarray over a slurped buffer, byte offsets, endianness, and `buffer/` and `int/` helpers. The issue suggests a "parse a binary header" example.
