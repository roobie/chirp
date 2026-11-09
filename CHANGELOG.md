# Changelog

What changed for people who use chirp, newest first; the binary carries this file so it can be read offline.

## Unreleased

### Added

- The help topic `tasks` (`chirp --help read tasks`) lists what the bundled modules do by goal: reading JSON, printing a table, validating data, hashing, running a program and so on. Each goal names the module, its import line and a short example that runs as it is, and says so when nothing bundled does it (CSV, XML). `chirp --help query` ranks these goals above other entries that match about as well, so a query in your own words, such as `print a table` or `json`, finds the module first.
- Importing a bundled module by a short name, such as `(import json)` or `(import toml)`, fails with the import that works, `(import spork/json :as json)`, and points at `chirp --help read tasks`, instead of only listing the paths Janet searched. A module of that name on disk still loads first.
- `(doc tarray/new)` explains its arguments: the offset counts bytes into a buffer and the size and stride count elements, a buffer or string is copied while a typed array or `ta/buffer` is shared, and numbers are in the host's byte order. spork's own docstring says only "Create new typed array." The `tasks` topic shows how to parse a binary file header.
- `chirp --help read modules` lists every bundled module with a goal it serves. It replaces the command in the `chirp` topic, which read `module/cache` and so missed the 9 TLS modules that load on first use.
- The help topic `surprises` (`chirp --help read surprises`) lists Janet behaviour that trips up scripts, each with the way around it: `sort` is not stable, program arguments must be strings rather than buffers, `ev/read` returns nil on empty output, `os/mkdir` makes one directory, a table cannot hold nil, `=` compares tables by identity, `in` raises where `get` returns nil, `length` counts bytes, and how to find the running chirp. The `sqlite` topic notes that FTS5 has no stopword list.

### Changed

- `chirp -v` and `chirp --version` print a second line with the project site, https://roobie.github.io/chirp/. The REPL banner is unchanged. A script that reads the version should take the first line, for example `chirp --version | head -n1`.

### Fixed

- The dev-proc skill's SKILL.md names its script as `scripts/dev-proc.janet`, relative to the skill's own directory, so the path also holds after `chirp --dev-proc --install -g`. It used to say `.claude/skills/dev-proc/scripts/dev-proc.janet`, which exists only in a project install, so an agent following a global install got `could not find file`. Run `chirp --dev-proc --install --force` (with `-g` for a global install) to pick up the new wording.
- On windows, jsec's error message buffers are per thread, as jsec intends, so two threads doing TLS at once no longer overwrite each other's error text. The compiler had been ignoring jsec's thread-local marker.

## 0.9.0

Released 2026-11-08.

### Changed

- chirp is built on Janet 1.43.0 (it was on a development build between 1.42.1 and 1.43.0). Janet 1.43.0 checks bytecode more strictly, so `unmarshal` refuses a corrupt image instead of crashing. It also fixes peg matching on a buffer that changes during the match, a use-after-free when a buffer is formatted into itself with `%s`, and `debug/stack` reading an invalid environment. A function with more than 256 closures now fails to compile, where it was compiled wrong before.

## 0.8.0

Released 2026-11-05.

### Added

- The dev-proc skill takes an out-of-band work dir of your own: `git config dev-proc.root <path>`, with any name, inside the repo (git-ignored) or anywhere else. The CLI uses it before the nearest `.work/`. `find` and `check` cover it too, but the commit hooks and `trailers` never ask for it or name it, so it stays out of the team's commits.
- A committed `.dev-proc.toml` with `work_dir = ".tasks"` renames that directory's dev-proc work dir for every clone; without the file it stays `.work`. `dev-proc dig` searches the whole repo by id, so records from before a rename are still found.
- A dev-proc work dir without git history (in no repo, or git-ignored in the one it sits in) keeps what `close` and `record --supersedes` remove: they move it to the work dir's `closed/` instead of deleting it, and `dig` reads it from there. `record --supersedes` no longer prints a `Supersedes:` trailer for an out-of-band work dir.
- The dev-proc skill runs in a directory that is not in a git repo: it uses the nearest work dir up to `/`, or `--root`, and the commands that need git (`trailers`, `check-msg`, `check --staged`, `hooks`, `report`) say so.
- dev-proc takes `DEV_PROC_ROOT=<absolute dir>` as the default for `--root`, in or out of a git repo, so a directory can pin its work dir (with direnv, say); `init` creates it. Any option that holds for every command gets a `DEV_PROC_<NAME>` variable the same way.
- `dev-proc report [<range>] [--since <date>] [--json]` sums up a stretch of git history: the units delivered, scrapped and still open, with commit counts and parents, and the records added and removed. With no range it covers the last tag to HEAD.

### Changed

- chirp trusts what the OS trusts. On macOS it uses the roots the keychain trusts for TLS (system, admin and user trust settings) instead of `/etc/ssl/cert.pem`, a snapshot the OS does not keep current: sites whose roots it lacked, example.com among them, failed with `certificate verify failed`. On windows it uses the certificate store's trusted roots, so HTTPS no longer needs `SSL_CERT_FILE`. Both are exported to `chirp/os-roots.pem` in the user's cache directory when a script first loads `jsec` or `spork-https` (reading the keychain takes a few hundred milliseconds), and `chirp --version` names the store. Linux and the BSDs keep using the system CA bundle file. `SSL_CERT_FILE` still overrides all of them.

### Fixed

- HTTPS on windows works when the server is more than a few milliseconds away. jsec's `tls/connect` started the TLS handshake before the TCP connection was made, so requests and `chirp --self-update` failed with `Write syscall error: WSA error 10057` (#10). An older chirp on windows that hits this cannot self-update to the fix; download the new release by hand.
- `NOTICES-windows-x64.txt` includes the licenses of gdtoa and winpthreads, two parts of mingw-w64 that the windows binary links and whose terms its mingw-w64 notice does not cover. Releases up to 0.7.0 lacked them.

## 0.7.0

Released 2026-11-02.

### Added

- `gzip` and `tar` modules (`chirp --help read archives`). `gzip` compresses and decompresses gzip data, whole or in pieces; `tar` lists, extracts and creates tar archives, gzipped or not, without a `tar` on the host. Extraction refuses entries that would land outside the target directory.
- The REPL edits lines: history, cursor movement, Tab completion and Ctrl-G docstrings, through the bundled spork/getline.
- The help topic `subprocess` (`chirp --help read subprocess`): running a program in another directory, and changing one environment variable without losing the rest.
- The dev-proc skill takes `--` to end its options, so text that starts with `--` can follow: `note <unit> log -- "--force was needed"`.
- `chirp --self-update --output PATH` saves the verified latest release at `PATH`, or inside it when it is a directory, without replacing the running chirp.

### Fixed

- `chirp --help query` and the `--help serve` search box find a name with punctuation, such as `dev-proc`, `spork-https`, `os/spawn` or `table?`, and list the bindings and topics whose id or title hold it first. Such names used to fail with an FTS5 error (`no such column` or a syntax error) unless quoted.
- Search results from the help topics quote their text, not their Markdown, so `chirp --help query` and the `--help serve` results no longer show backticks and code fences; the `--help serve` results also highlight the matched words.
- `os/execute` and `os/spawn` take `:cd` in their options table on linux, to run the child in that directory without moving the whole script with `os/cd` (#5). Janet has the option, but on linux it only turned it on for glibc, so chirp's musl build failed with `:cd argument not supported on this system`. windows and macOS already had it.
- `chirp --self-update` where the binary is writable but its directory is not (#7). It used to stop with `cannot write …/chirp.new`. A running chirp can only be replaced by a new file renamed over it, which needs the directory, so it now saves the verified release in a new temporary directory, exits non-zero, and prints the path and a command that installs it.

## 0.6.0

Released 2026-10-30.

### Added

- The dev-proc skill (`chirp --dev-proc --install`) needs fewer hand edits. `new` takes `--criterion`, `--purpose` and `--execute`, so a unit can be created and pass its gate in one command. `new` and `record` take section text from `--body-file` or `--body -` (stdin), and print just the id with `--id` or a JSON object with `--json`. `note <unit> now|next|evidence|harvest|log "…"` writes a unit's working sections, and `trailers` prints the `Work:` lines for what is staged.

### Fixed

- dev-proc dates follow the local calendar day; they were the UTC day, so late-evening or early-morning work could be dated a day off.

## 0.5.0

Released 2026-10-30.

### Added

- `chirp --help serve [--host H] [--port N]` serves the offline help as a local web page at `http://127.0.0.1:3111/`: the topic list, search as you type, and every topic, section and docstring on its own page. It listens on localhost only unless `--host` says otherwise, uses the project site's look, and needs no network.
- `chirp --help read <id> --source` prints a binding's definition after its docstring, and the `chirp --help serve` page of a binding shows it under the docstring, each with its `file:line`. It covers the Janet code of core, the bundled modules and chirp's overlays, and the C of Janet's core functions; it is inside the binary, so it works offline, and it is not searched.
- `chirp --dev-proc --install` writes the dev-proc agent skill (how work is run in a repo with a `.work/` directory) from the binary alone, so no checkout is needed. The files go to `.agents/skills/dev-proc` and `.claude/skills/dev-proc` is a relative link to them, the layout the npm `skills` package uses; `-g` installs under the home directory instead and `--copy` writes a real copy in place of the link. Installing again changes nothing when the copy is identical; a copy you have edited is refused unless you pass `--force`, which rewrites only the shipped files; files you added are left alone; and a `.claude/skills/dev-proc` that is not this link is never replaced. The installed skill runs with `chirp .claude/skills/dev-proc/scripts/dev-proc.janet`.

### Changed

- The offline help and the updater are now flags like the rest of chirp's own commands: `chirp --help query '<words>'`, `chirp --help read <id>` and `chirp --self-update` (`-h` still works for `--help`, and bare `chirp -h` now ends with the list of help topics). This frees the words `help` and `self-update` for your own scripts: `chirp help a b` runs a file named `help` like any other script. The old forms `chirp help …` and `chirp self-update` are gone, with no hint left behind. Asking `--help` about a word it does not know exits 2.

### Fixed

- The sqlite help said query rows are tables; they are structs, which cannot be changed in place. It now says so and points to `(thaw row)` for a mutable copy.

## 0.4.0

Released 2026-10-28.

### Added

- `pcre2`, Perl-style regular expressions on PCRE2 10.49: `pcre2/compile`, `pcre2/match`, `pcre2/find-all`, `pcre2/replace`, `pcre2/replace-all`, `pcre2/split` and `pcre2/version`. Patterns are UTF-8 by default and support named groups; replacements take `$1`, `${name}` and `$$`. Matching is bounded by `:match-limit`, `:depth-limit` and `:heap-limit`, all with defaults, so a runaway pattern fails with an error naming the limit instead of hanging.
- `md4c`, Markdown to HTML on md4c 0.6.0: `md4c/to-html` and `md4c/version`. The default is plain CommonMark; `:github` turns on GitHub's dialect, and each extension (tables, footnotes, task lists and others) can be set on its own. `:no-html` drops raw HTML from the input.
- `lexbor`, HTML parsing and CSS selectors on lexbor 3.0.1: `lexbor/parse` parses HTML as a browser does, `lexbor/select` and `lexbor/select-first` find elements by selector in document order, and `lexbor/text`, `lexbor/attr`, `lexbor/attrs`, `lexbor/tag`, `lexbor/html` and `lexbor/inner-html` read what was found. Nodes are handles that keep their document alive, compare equal when they are the same node, and can be searched in turn.

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
