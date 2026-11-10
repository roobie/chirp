# self-update

`chirp --self-update` replaces the running chirp with the latest release for its own platform, after checking that the release was signed with the key built into this binary.

```sh
chirp --self-update --check     # show current and latest version; change nothing
chirp --self-update             # update if the latest release is newer
chirp --self-update --force     # also install a build of the same version, or from a pre-release chirp; never an older one
chirp --self-update --output DIR   # save the verified build in DIR, newer or not; change nothing
chirp --self-update --base URL --key release-key.pem   # a mirror
```

## What is trusted

Only the signature. chirp fetches `SHA256SUMS` and `SHA256SUMS.sig` and verifies the Ed25519 signature before it reads anything in the file. The release version and the expected sha256 of the binary then come from the signed file, so a tampered mirror or release asset is refused. Without `--force`, chirp updates only to a release that is newer than itself; with it, to one of the same version as well. An older signed release is never installed, so replaying one cannot downgrade chirp. `--output` installs nothing, so it saves any verified build.

The signature does not say which workflow run built the binary. That can be checked separately with `gh attestation verify <file> --repo roobie/chirp`.

## Pre-release builds

A version with a suffix, such as `0.2.0-dev`, is a build from the main branch, not a release. It refuses to update unless given `--force`, because replacing it would silently drop whatever it was built to try. Builds from main between two releases all report the same version, so `--force` is also how a later one is taken; the signature and checksum are checked just the same.

## Where it writes

The new binary is written next to the running one and renamed over it, so a failure leaves the old binary in place. A running program cannot be rewritten in place, so this needs write permission on the directory, not only on the file. chirp never asks for elevated rights: if the directory is not writable, it still downloads and verifies the release, saves it in a new directory under the system temporary directory, exits non-zero, and prints the path and a command that installs it.

`--output PATH` saves the verified release at `PATH`, or inside it under its release name when `PATH` is a directory, and leaves the running chirp alone. It saves the signed build whether or not it is newer than the running chirp, and a pre-release build needs no `--force` for it. On Windows a running program cannot be overwritten, so the old one is renamed to `chirp.exe.old` first; it is removed by the next update.

Any failure prints its reason on stderr and exits non-zero.

## Mirrors

`--base URL` replaces `https://github.com/roobie/chirp/releases`. The URL may be plain `http://`, because the signature protects the content. A mirror is a plain file tree, with the signed files at the first two paths and the binaries below `download/`:

```
latest/download/SHA256SUMS
latest/download/SHA256SUMS.sig
download/v<version>/chirp-<version>-<target>
```

`SHA256SUMS` is in `sha256sum` format and lists `chirp-<version>-<target>` for every target; the Windows binary ends in `.exe`. The targets are `linux-x64`, `linux-arm64`, `macos-arm64` and `windows-x64`. `SHA256SUMS.sig` is the raw 64-byte Ed25519 signature over the exact bytes of `SHA256SUMS`. `--key` names a PEM file with the matching public key; without it chirp uses the key it was built with.
