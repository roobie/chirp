---
created: 2026-10-24
---

# B-U6C4GF5ICCTMVVBL Find how config.jdn content reaches the image

## Why
Adding a key to tools/build/config.jdn that the image never reads moved the linux-x64 hash (484a2667… → 9714e68b…). Builds still agree with each other, so reproducibility holds, but an unexplained input to the image is the kind of thing that later breaks it. Until it is understood, any config.jdn edit is a hash change, and releases from before and after it can't be compared.

## Notes
- tools/build/image.janet parses config.jdn in the image-building process. A likely cause is that the parsed data's allocation shifts the hash order of something that does get marshalled. L-ZI52YKRRPPUHTQEI shows the same kind of effect through the gensym counter, but parsing data calls no gensym, so that alone does not explain it.
- Repro: add an unused key to config.jdn, build linux-x64, and compare.
