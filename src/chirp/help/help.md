# chirp --help

Offline docs, built into the binary: the topics listed by `chirp -h`, plus the docstring of every bundled module binding and every Janet core binding.

```sh
chirp -h                                # usage, the topic list, then Janet's options
chirp --help query '<fts5 query>'       # ranked search, up to 10 hits
chirp --help query '<fts5 query>' --limit 3
chirp --help read <id>                  # print one hit in full
chirp --help serve [--host H] [--port N]   # browse the help at http://127.0.0.1:3111/
```

`-h` and `--help` are the same. A word after them that is not `query`, `read` or `serve` is an error and exits 2.

## Browsing

`serve` is for reading and searching in a browser instead of a terminal. It shows the same entries as `query` and `read`, with the same search syntax, and links each topic to its sections and back. By default it listens on localhost only, so nothing else on the network can reach it. `--host 0.0.0.0` binds all interfaces, which exposes the help to the network; the pages themselves need no network. If the port is taken it says so and exits 1; pick another with `--port`. Ctrl-C stops it.

## Query examples

Queries use SQLite FTS5 syntax. Words are stemmed, so `certificate` also finds `certificates`.

```sh
chirp --help query certificate             # one word
chirp --help query 'user agent'            # both words, anywhere in the entry
chirp --help query '"user agent"'          # the exact phrase
chirp --help query 'cert*'                 # prefix: cert, certs, certificate...
chirp --help query 'toml OR json'          # either word
chirp --help query 'sqlite NOT fts5'       # the first, without the second
chirp --help query 'title:server'          # only in titles
chirp --help query 'id:sh'                 # only in ids, e.g. the spork/sh bindings
chirp --help query 'NEAR(read stream, 5)'  # within 5 words of each other
```

Hyphens and other punctuation need a quoted phrase: `chirp --help query '"spork-https"'`. An invalid query prints the FTS5 error and exits 1.

## Ids

`chirp --help read` takes an id as printed by a query:

- `https`: a whole topic file
- `https/the-ca-option`: one `##` section of a topic
- `spork-https/get`: the docstring of a bundled module's binding
- `os/spawn`: the docstring of a Janet core binding

An unknown id exits 1 and suggests ids that contain it.
