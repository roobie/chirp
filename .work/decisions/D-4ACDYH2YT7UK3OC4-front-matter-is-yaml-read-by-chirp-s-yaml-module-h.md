---
status: accepted
date: 2026-10-25
read_if:
  - changing how front matter is parsed or written
  - a .work document fails to parse
refs:
  - .claude/skills/dev-proc/scripts/frontmatter.janet#decode-fm
  - .claude/skills/dev-proc/scripts/frontmatter.janet#yaml-scalar
---

# D-4ACDYH2YT7UK3OC4 Front matter is YAML read by chirp's yaml module, held to strings and lists of strings

## Context
The Node version had its own parser for a restricted subset that looked like YAML but was not. Once chirp had bundled libyaml, keeping a second hand-written parser meant owning code the binary already provides (BR, 2026-10-25).

## Decision
Front matter is decoded as YAML. Every value must be a string or a list of strings, and anything else is an error. dev-proc quotes a value it writes whenever that value would not read back as the same plain string.

## Why
Real YAML lets editors and other tools read the files. Without the type check, YAML quietly changes meaning: in twc, criteria that contain `: ` decode as mappings, and `true` or `1.5` turn into a bool or a number. Quoting on write keeps the documents dev-proc writes valid, and plain values stay unquoted, so ordinary output did not change.

## Consequences
Malformed front matter now reports libyaml's error instead of the old custom messages. A few inputs the old parser accepted are rejected, such as a list item that starts with `[` or a backtick. A few it rejected are now accepted. A decoded mapping has no key order, so the order is recovered from the text (B-JQKB2VOCY6XQW5V6).
