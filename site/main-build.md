# Latest build from main

**This is not a release.** It is the build of the `main` branch at commit [`@SHORT@`](https://github.com/roobie/chirp/commit/@COMMIT@), reporting version `@VERSION@`. Every push to `main` replaces it, and every build between two releases reports the same version, so the commit is what tells builds apart. A build from `main` may contain changes that are not in any release and may be broken. Releases are listed under [Downloads](../README.md#downloads).

## Install

```sh
chirp --self-update --channel main --force
```

`--force` installs the build in this tree even when it has the same version as the running chirp, though never an older one. Every build from `main` between two releases reports the same version, so chirp cannot tell that a later one is newer, and `--force` is how it is taken; a chirp that is itself a build from `main` also asks for it. Add `--output PATH` to save the verified file instead of replacing chirp, and `--check` to see what the tree holds without installing.

The tree is signed with a key of its own, built into chirp for `--channel main` and used for nothing else. The release key never verifies this tree, and this key never verifies a release, so `--self-update` without `--channel main` can never be given a build of `main`. It installs nothing it does not verify.

## Files

@FILES@

To check a download by hand, see [Verifying a download](../README.md#verifying-a-download). The same files are the ones a release would carry, under the same names, with the checksums in `SHA256SUMS` and its signature in `SHA256SUMS.sig`.
