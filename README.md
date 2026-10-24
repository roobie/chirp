# chirp

**chirp is an unofficial build of [Janet](https://janet-lang.org). It is not a Janet release and is not made by Janet's maintainers.** Please report problems with chirp here, not to Janet.

Stock Janet has no TLS and no HTTP server. chirp is a single binary that adds both, so a script can act as an HTTPS client or server with nothing installed except chirp.

```sh
chirp                    # REPL, like janet
chirp script.janet       # run a script, like janet
chirp --version          # chirp 0.1.0 (unofficial build, not a Janet release) on Janet …
```

Inside chirp, every bundled module can be imported without anything on disk:

```janet
(import spork-https :as https)
(print ((https/get "https://example.com/") :status))
```

From 0.2.0, scripts can also keep data in SQLite and read configuration from TOML:

```janet
(import sqlite3)
(import tomlin)
(def db (sqlite3/open "notes.db"))
(sqlite3/eval db "CREATE TABLE IF NOT EXISTS notes (body TEXT);")
(print ((tomlin/toml->janet (slurp "config.toml")) :title))
```

## What it bundles

Each component is pinned to an exact upstream commit in [`pins.jdn`](pins.jdn). None of them is forked.

| Component | What it adds | License |
|---|---|---|
| [Janet](https://github.com/janet-lang/janet) | the language and runtime | MIT |
| [spork](https://github.com/janet-lang/spork) | the standard library extras, including `spork/http` and `spork/zip` (zlib and zip, via miniz) | MIT |
| [jsec](https://github.com/llmII/jsec) | TLS and DTLS streams for `ev`, certificates, crypto | ISC |
| [spork-https](https://github.com/llmII/spork-https) | an HTTPS client and server on top of `spork/http` | ISC |
| [janet-lang/sqlite3](https://github.com/janet-lang/sqlite3) | `sqlite3`, Janet bindings to an embedded [SQLite](https://sqlite.org) (the amalgamation, so no system library is needed); from 0.2.0 | MIT (binding), public domain (SQLite) |
| [tomlin](https://github.com/pyrmont/tomlin) | `tomlin`, a TOML parser written in Janet; from 0.2.0 | MIT |
| [OpenSSL 3](https://github.com/openssl/openssl) | statically linked under jsec | Apache-2.0 |

Every release ships a `NOTICES-<target>.txt` with the full license texts of everything linked into that target's binary.

## Downloads

Releases are on the [releases page](https://github.com/roobie/chirp/releases). Each release has:

| Asset | For |
|---|---|
| `chirp-<version>-linux-x64` | Linux x86-64, static (musl), any distribution |
| `chirp-<version>-linux-arm64` | Linux arm64, static (musl), any distribution |
| `chirp-<version>-macos-arm64` | macOS 11+ on Apple silicon |
| `chirp-<version>-windows-x64.exe` | Windows x64 |
| `NOTICES-<target>.txt` | third-party license texts for that binary |
| `SHA256SUMS` | the sha256 of every asset |

On Linux and macOS, make the binary executable with `chmod +x`. macOS binaries are signed ad hoc, not by an Apple developer ID, so a downloaded one is quarantined. After verifying it, remove the quarantine flag with `xattr -d com.apple.quarantine chirp-<version>-macos-arm64`.

## Verifying a download

Every binary is built twice by CI, in different directories on different runners, and the release is only published when both builds produce the same sha256. Two checks tell you that a download is the file CI built.

1. The checksum. Download `SHA256SUMS` next to the binary, then run:

   ```sh
   sha256sum -c SHA256SUMS --ignore-missing        # Linux
   shasum -a 256 -c SHA256SUMS --ignore-missing    # macOS
   ```

2. The build provenance. GitHub attests which workflow run and commit produced each asset. With the [GitHub CLI](https://cli.github.com):

   ```sh
   gh attestation verify chirp-<version>-linux-x64 --repo roobie/chirp
   ```

Because the build is reproducible, you can also rebuild a release from its tag with `sh tools/build/container.sh <target> <outdir>` (this needs Docker) and compare the hashes.

## TLS certificates

chirp checks certificates by default. At startup it uses `SSL_CERT_FILE` if that is set. Otherwise it looks for the system's CA bundle in the usual Linux and macOS locations, and `chirp --version` shows which bundle it found.

**Windows has no CA bundle file, so for now HTTPS on Windows needs `SSL_CERT_FILE`.** Point it at a PEM bundle, for example the [curl CA bundle](https://curl.se/ca/cacert.pem) or the `ca-bundle.crt` that ships with Git for Windows (in `ucrt64` in current versions, `mingw64` in older ones):

```powershell
$env:SSL_CERT_FILE = "C:\Program Files\Git\ucrt64\etc\ssl\certs\ca-bundle.crt"
```

A later release will embed a pinned CA bundle as a fallback.

## How chirp's spork-https differs

From 0.2.0, chirp layers two fixes over the bundled spork-https client, without forking it:

- A request with no `User-Agent` header sends `User-Agent: chirp/<version>`, because some services, GitHub's API among them, reject requests without one. A `User-Agent` you set is sent unchanged.
- `:tls-opts {:ca "ca.pem"}` makes the client trust that CA, as the spork-https docs describe. jsec's client otherwise ignores `:ca` and falls back to the system store.

The server is unchanged.

## Building

The build needs Docker. It runs in a pinned Alpine container, where zig cross-compiles every target from Linux:

```sh
sh tools/build/container.sh linux-x64 out/      # or linux-arm64, macos-arm64, windows-x64
```

The targets are defined in [`tools/build/config.jdn`](tools/build/config.jdn).

## License

chirp's own code is under the [MIT license](LICENSE). Bundled components keep their own licenses; see the table above and the release notices.
