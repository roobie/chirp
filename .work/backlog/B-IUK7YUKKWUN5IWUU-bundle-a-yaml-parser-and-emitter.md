---
created: 2026-10-25
---

# B-IUK7YUKKWUN5IWUU Bundle a YAML parser and emitter

## Why
YAML is everywhere a script reaches for configuration: CI workflows, Kubernetes, compose files, Markdown front matter. chirp already bundles JSON and TOML, so YAML is the obvious missing battery (BR, 2026-10-25). The dev-proc port (B-GFASGZA3FO4XHJAV) needs front matter as well.

## Notes
- Options to weigh: a pure-Janet library, a C library such as libyaml behind a native module, or a chirp-owned subset. A pure-Janet library fits the reproducible static build most easily. A subset would be a worse copy of YAML that chirp then owns.
- Emitting matters as well as parsing, for tools that rewrite files.
- Follow the bundle pattern: pin it in pins.jdn, add a NOTICES entry and a smoke check, and record the choice as a decision, as was done for tomlin (D-DMR3ULVUY2KA72XN).
