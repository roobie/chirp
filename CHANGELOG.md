# Changelog

What changed for people who use chirp, newest first; the binary carries this file so it can be read offline.

## Unreleased

### Added

- `chirp --changelog` prints this file, and `chirp help read changelog` reads it from the help.
- Release notes include the release's section of this file.

## 0.2.0

Released 2026-10-24.

### Added

- `sqlite3`, bindings to an embedded SQLite with FTS5 full-text search, and `tomlin`, a TOML parser.
- `chirp help`: offline help inside the binary. `chirp help query '<fts5 query>'` searches the help topics and the docstrings of every bundled module and of Janet's core; `chirp help read <id>` prints a result in full.
- `chirp self-update` replaces the binary with the latest release, after checking the release's `SHA256SUMS` against its Ed25519 signature `SHA256SUMS.sig` with a key built into chirp. `--check` only reports; a build whose version carries a suffix such as `-dev` refuses unless `--force` is given.
- Code piped to chirp, or given as `chirp -`, runs as a script.

### Changed

- The bundled spork-https client sends `User-Agent: chirp/<version>` when the request sets none, and honors `:tls-opts {:ca "ca.pem"}`, which jsec's client otherwise ignores.
- Bare `chirp` with a pipe as stdin no longer starts a REPL: there is no banner, prompt or echoed value, and a failing script shows in the exit status.

0.1.0 cannot self-update; install 0.2.0 by hand once.

## 0.1.0

Released 2026-10-24.

First release: an unofficial build of Janet that adds TLS and an HTTPS client and server to a single binary.

### Added

- Static binaries for linux-x64, linux-arm64 (static musl, any distribution), macos-arm64 and windows-x64.
- Janet, spork (including `spork/zip`), jsec TLS and DTLS with a statically linked OpenSSL 3, and spork-https, bundled so every module imports with nothing on disk.
- TLS trust: `SSL_CERT_FILE` if set, otherwise the first system CA bundle found in the usual Linux and macOS locations. `chirp --version` shows which one.
- Reproducible builds: CI builds every target twice and publishes only when both hashes match.
- `SHA256SUMS`, a GitHub build-provenance attestation for every asset, and a `NOTICES-<target>.txt` with the license texts of everything linked into that binary.
- `--version` and the REPL banner say the build is unofficial and not a Janet release.

### Known issues

- Windows has no CA bundle file, so HTTPS there needs `SSL_CERT_FILE` pointing at a PEM bundle.
