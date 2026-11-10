---
status: accepted
date: 2026-11-10
read_if:
  - changing how builds of main are published or downloaded
  - changing the pages workflow triggers
  - changing who or what may sign with the release key or the main-build key
refs:
  - tools/release/layout.janet
  - .github/workflows/pages.yml
  - src/chirp/update.janet#verified-sums
  - src/chirp/update.janet#resolve-trust
  - src/chirp/chirp.jdn
  - src/chirp/main-build-key.pem
---

# D-6NWFV37OBOERI3AF Builds of main are published on the Pages site as a signed, release-shaped latest tree

## Context
The owner wants a download of main between releases, for example to try a dev-proc change with `chirp --dev-proc --install`. Builds exist only as CI artifacts, which need a GitHub login and expire. GitHub immutable releases are on for this repo, so a rolling release that is replaced on every push cannot exist. The site itself follows main on every green push (D-7TDUEHUOFXPTSQCE); this record is about the build it carries.

## Decision
The site carries a signed tree shaped like a release under `latest/`, which `chirp --self-update --channel main` reads from `https://roobie.github.io/chirp/latest`, for the build of the commit it was published from. The tree is signed by the same script that signs releases, with a key of its own, and the site has a plain page that says what the build is and links its files. A commit whose version has no `-` suffix is a release cut, not a build of main, and gets no tree.

## Why
- **A rolling GitHub release or prerelease:** impossible with immutable releases.
- **A new self-update layout or a second client path:** rejected. update.janet already trusts only a signed SHA256SUMS in a static tree (D-44BH6MURMXC5JTOB), so the Pages site only has to hold the same tree. The doubled `latest/latest/download/` segment follows from that: a base is a prefix under which the client looks for `latest/download/SHA256SUMS`, and the base is `<site>/latest`. The base is kept as `https://roobie.github.io/chirp/latest` because the owner was given that URL and `--channel main` hides the base from users, so it is a path that mirrors and notes can keep naming. The client does change, by a channel that selects a base and a key, but not in how it reads, verifies or installs a tree.
- **A separate key, trusted through `--channel main`:** chosen. The release key keeps meaning "a release". chirp trusts the main-build key only when asked for the main channel and the release key only otherwise, so a build of main can never reach a release user through a bad `--base`: the release key never signs one, and the main key is not accepted without the channel. A leaked or rotated main key costs only the people using the main channel. The private key is the secret of a GitHub environment limited to main, read by the one job that signs; the public key is in the repo beside the release key.
- **Signing with the release key:** rejected. Every main build would stay signed, and installable by any chirp given the base, for as long as the tree is served or mirrored, under the key all users trust; the release key could then not be rotated without also invalidating main builds, and the signing job would need the key that protects releases. The release key is kept apart, in an environment of its own (D-S23WKXKSMWMABF53).
- **Unsigned, with provenance attestation only:** rejected. Without a signature the main channel cannot use self-update's trust rule (D-44BH6MURMXC5JTOB), so a build of main would be a manual download.
- **One script for release and pages:** the layout and signing shell was in release.yml; copying it into pages.yml would let the two drift apart in names, listing or signature check, and the shell was untestable. In Janet, run by chirp, it has a test with fake binaries and a throwaway key.

## Consequences
- Every main build reports the same `X.Y.Z-dev` version. `--self-update --force` installs a build of the same version, and `--output` saves any verified build, so a later build is taken by asking; `--force` still refuses an older version, so it cannot downgrade; a plain `--self-update --check` cannot tell one main build from another.
- A release deploy has no main build, so `latest/` is absent from the site until the next push to main. The push that moves main to the next `-dev` normally follows a release within minutes. A release run publishes only if the tagged commit is still main's tip; when main has moved on, the newer deploy already carries the release and the tag's run publishes nothing, so it cannot put an older site over it.
- Only the newest build of main is kept: the site is replaced whole on every deploy, so there is no history of main builds to bisect.
- A workflow_run workflow always runs on the default branch, so the `github-pages` environment allows only the branch main (checked through the API), which is why a manual run on any other ref publishes nothing. The `main-build` environment holds the signing secret and allows main only.
- The main-build files are attested by the signing job, so `gh attestation verify` works on them as on a release.
- The release signing key is the secret of the `release` environment, which main and other branches cannot enter and a tag push enters only on the owner's approval (D-S23WKXKSMWMABF53).
- Rotating the main-build key needs a release of chirp that ships the new public key, as for the release key (D-44BH6MURMXC5JTOB); until then the main channel of older binaries fails to verify, and nothing else does.
- A main build is told apart from a release by its `-dev` version (D-2UB7VI5YR6ZBQ4FD), so even a plain self-update from a `-dev` chirp asks for `--force`.
