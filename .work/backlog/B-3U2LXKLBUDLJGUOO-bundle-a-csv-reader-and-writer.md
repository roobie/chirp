---
created: 2026-10-25
---

# B-3U2LXKLBUDLJGUOO Bundle a CSV reader and writer

## Why
CSV is the format spreadsheets, exports and reports arrive in, and spork has no CSV module. Splitting on commas breaks on quoted fields, so scripts need a real parser.

## Notes
- RFC 4180: quoted fields, doubled quotes, embedded newlines, CRLF or LF.
- Options worth having: delimiter (TSV), header row to tables, and a writer that quotes only when needed.
- Small enough for pure Janet (a PEG or a hand loop); C only if a benchmark shows the need (B-QCBMFCPRFJGNUXAH).
