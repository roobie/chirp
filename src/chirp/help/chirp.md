# chirp

chirp is an unofficial build of Janet. It is not a Janet release and is not made by Janet's maintainers. It is one static binary that bundles spork, jsec (TLS, with OpenSSL), spork-https, sqlite3, tomlin, yaml, pcre2 (Perl-style regular expressions), md4c (Markdown to HTML), lexbor (HTML parsing and CSS selectors) and omap (an insertion-ordered map that json and yaml can decode to and encode from), so scripts need nothing installed besides chirp.

## Usage

```sh
chirp                              # REPL; runs piped stdin as a script
chirp script.janet arg...          # run a script
chirp - arg...                     # run stdin as a script
chirp -v | --version               # version and identity
chirp --changelog                  # what changed in each release
chirp help                         # offline docs
chirp help query '<words>'         # search them
chirp help read <id>               # print one result
chirp self-update [--check] [--force]   # replace chirp with the latest release
chirp -h | --help                  # this text, then Janet's options
```

All other options (`-e`, `-l` and the rest) are Janet's own and are listed below.

## Version and identity

`chirp -v` (or `--version`) prints the chirp version, the Janet version it is built on, and the CA bundle it found, or `none found`. `chirp --changelog` prints what changed in each release; it is also the help topic `changelog`.

## Certificate authorities

TLS verifies certificates by default. At startup chirp uses the file named by `SSL_CERT_FILE` if that is set. Otherwise it takes the first of these that exists and sets `SSL_CERT_FILE` to it: `/etc/ssl/certs/ca-certificates.crt`, `/etc/pki/tls/certs/ca-bundle.crt`, `/etc/ssl/cert.pem`. Windows has no such file, so HTTPS there needs `SSL_CERT_FILE` set by hand; see `chirp help read https/windows-certificates`.

## Running scripts

`chirp script.janet arg...` runs the file. If it defines `main`, chirp calls it with the script path first, then the arguments:

```janet
(defn main [& args]
  (print "script: " (first args))
  (print "arguments: " (string/join (slice args 1) ",")))
```

Run as `chirp script.janet a b`, this prints `script: script.janet` and `arguments: a,b`. With no arguments on a terminal chirp starts a REPL. A script named `help` must be run as `./help`, because `chirp help` is the help command.

## Piping code in

When stdin is not a terminal, bare `chirp` runs it as a script instead of starting a REPL. There is no banner, no prompt and no echoed value, and an error goes to stderr with a non-zero exit status:

```sh
echo '(print "hi")' | chirp
echo '(error "boom")' | chirp    # boom on stderr, exit status 1
```

`chirp - arg...` runs stdin as a script whatever stdin is. If the code defines `main`, it receives `-` first, then the arguments, just as `chirp script.janet a b` passes the script path first:

```sh
echo '(defn main [& args] (print (string/join args ",")))' | chirp - a b
```

This prints `-,a,b`.

## One-liners

`-e` evaluates an expression. `-l mod` imports a module first, with no prefix, so its names are usable bare:

```sh
chirp -e '(print (+ 1 2))'
chirp -l spork/json -e '(print (encode {:a 1}))'
```

## Listing bundled modules

Every bundled module can be imported with nothing on disk. List them with:

```sh
chirp -e '(each k (sort (filter string? (keys module/cache))) (print k))'
```

Read a module's docs with `(doc ...)`, for example `chirp -e '(import spork/sh) (doc sh/exec-slurp)'`.

## Updating chirp

`chirp self-update` replaces the binary with the latest signed release; `--check` only reports. See `chirp help read self-update`.

## Offline help

`chirp help` lists the help topics. `chirp help query '<words>'` searches them and the docstrings of every bundled module and of Janet's core. `chirp help read <id>` prints one result in full. The text is inside the binary, so it works offline.
