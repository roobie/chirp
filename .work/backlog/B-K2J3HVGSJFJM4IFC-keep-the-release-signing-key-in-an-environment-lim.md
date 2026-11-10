---
created: 2026-11-10
---

# B-K2J3HVGSJFJM4IFC Keep the release signing key in an environment limited to v* tags

## Why
CHIRP_RELEASE_SIGNING_KEY is a repository secret, so a workflow on any branch can read it: the release workflow's dry run from a branch already signs that branch's build for seven days. The main-build key is in an environment limited to main (D-6NWFV37OBOERI3AF); the key that protects releases is less guarded than the one that protects builds of main. Moving it into a `release` environment whose deployment rule allows only `v*` tags would limit it to real releases. Decide first what the dry run does without it: skip signing, or sign with a throwaway key so the rest of the packaging is still proven.

## Notes
TODO
