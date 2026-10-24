---
status: accepted
date: 2026-10-24
read_if:
  - needing compression or zip archives
  - HTTP gzip content-encoding
  - considering adding zlib
refs:
---

# D-AD6YBCGFHJTVZ7TZ Compression via spork/zip (miniz), not zlib

## Context
BR added a z compression library (zlib or miniz) to the project's scope. The pinned spork already ships a native `spork/zip` module with miniz included. It offers zlib-format compress/decompress and zip archive reading and writing.

## Decision
Provide compression through spork's own `spork/zip` (miniz), linked statically together with spork's other native modules. Do not add zlib.

## Why
miniz comes with a pin we already have, along with a binding that is maintained upstream. zlib would need a new pin, plus a Janet binding that doesn't exist upstream and that we would have to write and maintain.

## Consequences
gzip framing (needed for HTTP `Content-Encoding: gzip`) is not part of `spork/zip`'s API. If it is needed, build it on top (a header and CRC around raw deflate) or raise it upstream; that alone does not justify adding zlib.
