# chirp

**A batteries-included scripting runtime in one static binary: download it, run your script.**

chirp is [Janet](https://janet-lang.org), a small, fast Lisp, built together with what real scripts reach for: an HTTPS client and server, JSON, SQLite with full-text search, TOML, YAML, compression, subprocesses, argument parsing and regexes. There is one file per platform (Linux x64 and arm64, macOS arm64, Windows x64). It is static, and needs no runtime, package manager or C compiler.

**chirp is an unofficial build of Janet. It is not a Janet release and is not made by Janet's maintainers.** Please report problems with chirp here, not to Janet.

**chirp is young and not yet stable.** It is used daily by its authors, but every 0.x release may still change chirp's own interfaces (its command line, `yaml`, `omap`) and move the pinned versions of what it bundles. Pin a release if a script must keep working, and read `chirp --changelog` before updating.

## Why chirp

Scripts tend to start small and then need one more thing: an API call, a config file, somewhere to keep state. In most languages that one thing means an install step. Python wants a matching interpreter, a virtualenv and pip. Shell wants curl, jq and sqlite3 to be present, at versions that agree. Stock Janet has no TLS at all, and adding it means a C toolchain and OpenSSL headers on every machine.

chirp removes that step. The batteries are inside the binary, so a script written on a laptop runs unchanged on a fresh server, in a CI job, in a `FROM scratch` container or on an air-gapped machine. The only setup is copying one file.

- **One file, nothing else.** Every bundled module imports with nothing on disk.
- **The same everywhere.** Every platform runs the same Janet and the same module versions, so behaviour does not drift between machines.
- **Verifiable.** Builds are reproducible: CI builds each target twice and ships only when both hashes match. Every release carries SHA256SUMS, an Ed25519 signature and GitHub build provenance.
- **Works offline.** `chirp help` searches the docs of every bundled module and of Janet's core, and `chirp --changelog` says what changed.
- **Keeps itself current.** `chirp self-update` installs the latest release only after checking its signature.

chirp does not fork Janet or its libraries. It pins upstream versions and bundles them, so Janet's own docs and community apply as they are.

## Using it

```sh
chirp                    # REPL, like janet
chirp script.janet       # run a script, like janet
echo '(print 1)' | chirp # run code from stdin
chirp --version          # chirp 0.3.0 (unofficial build, not a Janet release) on Janet …
chirp --help             # chirp's entry points, then Janet's options
chirp --changelog        # what changed in each release, offline
chirp self-update        # replace chirp with the latest signed release (--check only reports)
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

YAML is built in too. `yaml/decode` and `yaml/encode` work like `json/decode` and `json/encode`, and plain scalars follow the YAML 1.2 Core schema, so `no` stays a string:

```janet
(import yaml)
(def cfg (yaml/decode (slurp "config.yaml") true))
(print (cfg :title))
(print (yaml/encode {:name "chirp" :tags ["a" "b"]}))
```

A table has no order, so a script that rewrites a JSON or YAML file loses the author's key order. Pass a fourth argument, `ordered`, to `json/decode` or `yaml/decode` (or `yaml/decode-all`) and every object comes back as an `omap`, a map that keeps its keys in insertion order. `json/encode` and `yaml/encode` write an `omap` in that order, and a plain table as before:

```janet
(import omap)
(import yaml)
(def doc (yaml/decode (slurp "config.yaml") false false true))
(put doc "version" 2)                  # an existing key keeps its place, a new one goes last
(put doc "obsolete" nil)               # nil removes a key
(spit "config.yaml" (yaml/encode doc))
(print (omap/omap? doc) (keys doc))    # keys, get, put, in, pairs, eachp and length work as on a table
```

An `omap` is not a table, so `table?` and `dictionary?` are false for it and `deep=` does not compare it; a function that does not know the type fails loudly instead of dropping the order.

From 0.4.0, `pcre2` brings Perl-style regular expressions, the syntax that grep, sed and Python documentation use. A pattern is a string, or compiled once with `pcre2/compile`:

```janet
(import pcre2)
(pcre2/match "(?<year>\\d{4})-(?<mon>\\d\\d)" "on 2026-10-27")   # {0 "2026-10" 1 "2026" 2 "10" :mon "10" :year "2026"}
(pcre2/replace-all "(\\w+)@(\\w+)" "a@b c@d" "$2:$1")              # "b:a d:c"
(pcre2/split ",\\s*" "a, b,c")                                      # @["a" "b" "c"]
(pcre2/find-all "\\d+" "1 22 333")                                  # an array of matches
```

Matching is bounded by counts instead of time (`:match-limit`, `:depth-limit` and `:heap-limit`, all with defaults), so a pattern that backtracks without end stops with an error that names the limit, the same way on every machine. `chirp help query pcre2` lists the functions and their options.

## Help

`chirp help` lists the help topics, `chirp help query '<words>'` searches them and the docstrings of every bundled module offline, and `chirp help read <id>` prints a result in full. The text is inside the binary.

## What it bundles

Each component is pinned to an exact upstream commit in [`pins.jdn`](pins.jdn). None of them is forked.

| Component | What it adds | License |
|---|---|---|
| [Janet](https://github.com/janet-lang/janet) | the language and runtime | MIT |
| [spork](https://github.com/janet-lang/spork) | the standard library extras, including `spork/http` and `spork/zip` (zlib and zip, via miniz) | MIT |
| [jsec](https://github.com/llmII/jsec) | TLS and DTLS streams for `ev`, certificates, crypto | ISC |
| [spork-https](https://github.com/llmII/spork-https) | an HTTPS client and server on top of `spork/http` | ISC |
| [janet-lang/sqlite3](https://github.com/janet-lang/sqlite3) | `sqlite3`, Janet bindings to an embedded [SQLite](https://sqlite.org) (the amalgamation, so no system library is needed), with FTS5 full-text search enabled; from 0.2.0 | MIT (binding), public domain (SQLite) |
| [tomlin](https://github.com/pyrmont/tomlin) | `tomlin`, a TOML parser written in Janet; from 0.2.0 | MIT |
| [libyaml](https://github.com/yaml/libyaml) | `yaml`, YAML parsing and emitting: chirp's own small binding over libyaml 0.2.5, with Core schema scalars, anchors, aliases and merge keys; from 0.3.0 | MIT |
| [PCRE2](https://github.com/PCRE2Project/pcre2) | `pcre2`, Perl-style regular expressions: chirp's own small binding over PCRE2 10.49 (interpreter only, no JIT), with named groups, replacement with group references and split; from 0.4.0 | BSD-3-Clause with the PCRE2 exception |
| chirp itself | `omap`, an insertion-ordered map that `yaml` and `json` can decode to and encode from; written in C for chirp, with `json-omap`, a copy of spork's JSON decoder that builds it; from 0.3.0 | MIT |
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
| `SHA256SUMS.sig` | Ed25519 signature of `SHA256SUMS`, checked by `chirp self-update` |

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

The build needs Docker. It runs in a container image pinned by digest in [`pins.jdn`](pins.jdn) (Alpine plus the packages in [`tools/build/packages.txt`](tools/build/packages.txt)), which Docker pulls from a public registry. zig cross-compiles every target from Linux:

```sh
sh tools/build/container.sh linux-x64 out/      # or linux-arm64, macos-arm64, windows-x64
```

The targets are defined in [`tools/build/config.jdn`](tools/build/config.jdn).

## License

chirp's own code is under the [MIT license](LICENSE). Bundled components keep their own licenses; see the table above and the release notices.
