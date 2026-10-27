# Changelog

What changed for people who use chirp, newest first; the binary carries this file so it can be read offline.

## Unreleased

### Added

- `pcre2`, Perl-style regular expressions on PCRE2 10.49: `pcre2/compile`, `pcre2/match`, `pcre2/find-all`, `pcre2/replace`, `pcre2/replace-all`, `pcre2/split` and `pcre2/version`. Patterns are UTF-8 by default and support named groups; replacements take `$1`, `${name}` and `$$`. Matching is bounded by `:match-limit`, `:depth-limit` and `:heap-limit`, all with defaults, so a runaway pattern fails with an error naming the limit instead of hanging.
- `md4c`, Markdown to HTML on md4c 0.6.0: `md4c/to-html` and `md4c/version`. The default is plain CommonMark; `:github` turns on GitHub's dialect, and each extension (tables, footnotes, task lists and others) can be set on its own. `:no-html` drops raw HTML from the input.

## 0.3.0

Released 2026-10-25.

### Added

- `chirp -h` and `chirp --help` print chirp's own entry points (scripts, stdin, `help`, `self-update`, `--changelog`), then Janet's options.
- `yaml`, YAML decoding and encoding on libyaml: `yaml/decode`, `yaml/decode-all` and `yaml/encode`, shaped like `spork/json`. Plain scalars follow the YAML 1.2 Core schema, so `no` and `on` stay strings. Anchors, aliases and `<<` merge keys work, and an alias bomb fails with an error instead of exhausting memory.
- `omap`, an insertion-ordered map: `omap/new`, `omap/from-pairs`, `omap/pairs` and `omap/omap?`. `get`, `put`, `in`, `keys`, `values`, `pairs`, `eachp`, `length` and printing work as on a table; putting a key again keeps its place and putting nil removes it. It is not a table, so `table?` is false for it.
- `json/decode`, `yaml/decode` and `yaml/decode-all` take an optional `ordered` argument after `nils`; when truthy, objects and mappings come back as `omap`s in the order written. `json/encode` and `yaml/encode` write an `omap` in its own order, so a decode and encode round trip keeps the author's key order. Without the argument both behave as before: `json/decode` and `json/encode` still run spork's own code for anything that holds no `omap`.
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
