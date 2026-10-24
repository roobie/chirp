# self-update

`chirp self-update` replaces the running chirp with the latest release for its own platform, after checking that the release was signed with the key built into this binary.

```sh
chirp self-update --check     # show current and latest version; change nothing
chirp self-update             # update if the latest release is newer
chirp self-update --force     # also allow a pre-release build to update
chirp self-update --base URL --key release-key.pem   # a mirror
```

## What is trusted

Only the signature. chirp fetches `SHA256SUMS` and `SHA256SUMS.sig` and verifies the Ed25519 signature before it reads anything in the file. The release version and the expected sha256 of the binary then come from the signed file, so a tampered mirror or release asset is refused. chirp updates only to a release that is newer than itself, so replaying an old signed release cannot downgrade it.

The signature does not say which workflow run built the binary. That can be checked separately with `gh attestation verify <file> --repo roobie/chirp`.

## Pre-release builds

A version with a suffix, such as `0.2.0-dev`, is a build from the main branch, not a release. It refuses to update unless given `--force`, because replacing it would silently drop whatever it was built to try.

## Where it writes

The new binary is written next to the running one and renamed over it, so a failure leaves the old binary in place. chirp never asks for elevated rights: if the directory is not writable, the update fails and says so. On Windows a running program cannot be overwritten, so the old one is renamed to `chirp.exe.old` first; it is removed by the next update.

Any failure prints its reason on stderr and exits non-zero.

## Mirrors

`--base URL` replaces `https://github.com/roobie/chirp/releases`. The URL may be plain `http://`, because the signature protects the content. A mirror is a plain file tree, with the signed files at the first two paths and the binaries below `download/`:

```
latest/download/SHA256SUMS
latest/download/SHA256SUMS.sig
download/v<version>/chirp-<version>-<target>
```

`SHA256SUMS` is in `sha256sum` format and lists `chirp-<version>-<target>` for every target; the Windows binary ends in `.exe`. The targets are `linux-x64`, `linux-arm64`, `macos-arm64` and `windows-x64`. `SHA256SUMS.sig` is the raw 64-byte Ed25519 signature over the exact bytes of `SHA256SUMS`. `--key` names a PEM file with the matching public key; without it chirp uses the key it was built with.

A script named `self-update` must be run as `./self-update`, because `chirp self-update` is this command.
