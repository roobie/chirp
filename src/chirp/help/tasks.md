# Tasks: which module does what

Start here when you know what you want to do but not which module does it. Each section is a goal: the module to import, a short example that runs as it is, and where to read more. Every module chirp bundles is named below, so a goal not listed here has no bundled module.

`chirp --help read <id>` prints a binding's full docstring, such as `chirp --help read spork/misc/print-table`, and `chirp --help query '<words>'` searches everything.

## Read and write JSON

`spork/json` parses (decodes) JSON into tables and arrays and encodes Janet values back. There is no module named plain `json`, so import it with an alias.

```janet
(import spork/json :as json)

(def data (json/decode `{"name": "chirp", "tags": ["janet", "tls"]}`))
(print (data "name"))
(print (json/encode @{"ok" true "n" 3}))
```

`json/decode` takes three optional flags: keyword keys, `null` as nil, and ordered objects, so that a script that rewrites a file keeps the author's key order (next section).

## Keep the key order of a map

Janet tables have no order. An `omap` keeps keys in the order they were added, and `spork/json` and `yaml` encode it in that order. Their decoders return omaps when their `ordered` argument is true; `json-omap` is the JSON decoder behind that flag, not for calling directly. `=` tells two omaps apart by identity; `omap/equal?` compares them by content. An omap can be marshalled, so it can be saved in an image or sent to another ev thread.

```janet
(import omap)
(import spork/json :as json)

(def m (json/decode `{"b": 1, "a": 2}` false false true))
(print (json/encode m))                       # {"b":1,"a":2}
(print (json/encode (omap/new :z 1 :y 2)))    # {"z":1,"y":2}
```

## Read and write YAML

`yaml` decodes one document or a whole stream, and encodes Janet values as block YAML.

```janet
(import yaml)

(def cfg (yaml/decode "name: chirp\nports: [80, 443]\n"))
(print (cfg "name"))
(print (yaml/encode @{"retries" 3}))
```

## Read a TOML config file

`tomlin` parses TOML into tables with keyword keys. It does not write TOML. Integers come back as `int/s64`; the `toml` topic explains what that means for comparisons.

```janet
(import tomlin)

(def cfg (tomlin/toml->janet "title = \"chirp\"\n[owner]\nname = \"wren\"\n"))
(print (get-in cfg [:owner :name]))
```

## Read CSV

No CSV module is bundled. A file without quoted fields splits with `string/split`; a file with quoted fields, commas or newlines inside quotes, needs a parser, such as a PEG with `peg/match`.

```janet
(each line (string/split "\n" "name,age\nada,36")
  (pp (string/split "," line)))
```

## Read XML

No XML parser is bundled. `lexbor` parses HTML, not XML: it accepts most XML-looking markup but applies HTML's rules, which can rename or move elements.

## Print a table

`spork/misc/print-table` prints rows, tables or structs with the same keys, as a boxed text table; `spork/misc/format-table` writes the same into a buffer. It has no column alignment options, number formatting, or other output formats such as Markdown.

```janet
(import spork/misc)

(def rows [{:name "ada" :age 36} {:name "alan" :age 41}])
(misc/print-table rows)               # columns sorted by key
(misc/print-table rows [:name :age])  # columns in this order
```

## Validate data against a schema

`spork/schema` checks that data has the shape you expect. `schema/validator` returns a function that returns the data or raises an error saying which part failed; `schema/predicate` returns true or false. It checks without converting: a string `"36"` is not a number.

```janet
(import spork/schema)

(def check (schema/validator (props :name :string :age :number)))
(pp (check {:name "ada" :age 36}))
(pp (protect (check {:name "ada" :age "36"})))
```

## Compare two values and find the differences

`spork/data/diff` compares nested data and returns what only the first has, what only the second has, and what both share.

```janet
(import spork/data)

(pp (data/diff {:a 1 :b 2} {:a 1 :b 3}))
```

## Store data in a database

`sqlite3` is SQLite, built in. `":memory:"` opens a database that lives only as long as the script; a path opens or creates a file. The `sqlite` topic covers parameters, transactions and full-text search.

```janet
(import sqlite3)

(def db (sqlite3/open ":memory:"))
(sqlite3/eval db "CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)")
(sqlite3/eval db "INSERT INTO notes (body) VALUES (:b)" {:b "hello"})
(pp (sqlite3/eval db "SELECT * FROM notes"))
(sqlite3/close db)
```

## Fetch a URL or call an HTTP API

`spork-https` makes HTTPS and HTTP requests (`get`, `post`, `request`, `download`), trusting the operating system's certificates. `spork/http` does plain HTTP only. The `https` topic has examples, including a private CA.

## Download a file

`spork-https/download` writes a URL's body to a path; it follows redirects. The `https` topic shows it, and the `archives` topic unpacks what it fetches.

## Serve HTTP or HTTPS

`spork/http/server` serves plain HTTP with a handler function, and `spork/http/router` and `spork/http/logger` build the handler. `spork-https/server` does the same over TLS, given a certificate and key. `spork/httpf` builds a JSON API from functions marked with a `:path`. See the `https` topic.

## Run another program

`os/execute` runs a program and returns its exit code; `spork/sh/exec-slurp` returns its output. `spork/sh-dsl` offers shell-like pipelines with `$`, `$<` and `$?`. The `subprocess` topic covers working directories and environment variables.

```janet
(import spork/sh)

# chirp itself is the program here, so the example runs on any host.
(def janet-version (sh/exec-slurp (dyn *executable*) "-e" "(prin janet/version)"))
(print janet-version)
```

## Work with files, directories and paths

`slurp` and `spit` read and write whole files, and `os/dir`, `os/stat` and `os/rm` are core. `spork/sh` adds what core lacks: `create-dirs` (like `mkdir -p`), `copy`, `rm` (recursive), `exists?` and `list-all-files`. `spork/path` joins and splits paths.

```janet
(import spork/sh)
(import spork/path)

(def dir (path/join "out" "logs"))
(sh/create-dirs dir)
(spit (path/join dir "run.txt") "ok\n")
(print (sh/exists? (path/join dir "run.txt")))
(print (path/basename "out/logs/run.txt"))
(sh/rm "out")
```

## Parse command-line arguments

`spork/argparse/argparse` reads `(dyn :args)` against a list of options and prints usage on `--help` or bad input. It returns nil then, so check before going on.

```janet
(import spork/argparse)

(setdyn :args ["script" "--name" "ada" "-v"])
(def opts (argparse/argparse "Greets someone."
            "name" {:kind :option :help "who to greet" :default "world"}
            "verbose" {:kind :flag :short "v" :help "say more"}))
(when opts (print "hello " (opts "name") (if (opts "verbose") "!" "")))
```

## Match and replace text with regular expressions (regex)

`pcre2` is Perl-compatible regular expressions: groups, lookaround, named groups and `$1` replacements. `spork/regex` compiles a small regex subset into a PEG. Janet's own `peg` module is often the better tool for structured text.

```janet
(import pcre2)

(pp (pcre2/match `(\d+)-(\d+)` "pages 12-34"))
(print (pcre2/replace-all `\s+` "a   b  c" " "))
```

## Parse HTML and select elements

`lexbor` parses HTML the way a browser does and selects elements with CSS selectors.

```janet
(import lexbor)

(def page (lexbor/parse `<ul><li><a href="/a">A</a></li><li><a href="/b">B</a></li></ul>`))
(each a (lexbor/select page "a[href]")
  (print (lexbor/attr a "href") " " (lexbor/text a)))
```

## Render Markdown to HTML

`md4c` renders CommonMark, or GitHub's dialect with `{:github true}`, to HTML.

```janet
(import md4c)

(print (md4c/to-html "# Title\n\nSome *text*."))
```

## Generate HTML or text from a template

`spork/htmlgen` builds HTML from Janet data, escaping text. `spork/temple` compiles templates with embedded Janet for any text format.

```janet
(import spork/htmlgen)

(print (htmlgen/html [:p {:class "note"} "1 < 2"]))
```

## Compress files and work with archives

`gzip` reads and writes `.gz` data, whole or in pieces. `tar` creates, lists and extracts tar archives, gzipped or not. `spork/zip` reads and writes zip archives and zlib data. The `archives` topic covers them.

```janet
(import gzip)

(def packed (gzip/compress "hello hello hello"))
(print (gzip/decompress packed))
```

## Hash data, compute an HMAC, make random bytes

`jsec/crypto` has SHA-2 and other digests, HMAC, key derivation and secure random bytes. `spork/crc` computes CRC checksums, and `spork/base64` encodes and decodes Base64. Digests come back as raw bytes; encode them for printing.

```janet
(import jsec/crypto)
(import spork/base64)

(def sum (crypto/digest :sha256 "hello"))
(print (string/join (map |(string/format "%02x" $) sum)))
(print (base64/encode (crypto/hmac :sha256 "key" "message")))
(print (length (crypto/random-bytes 16)))
```

## Encrypt, sign, and handle keys and certificates

`jsec/crypto` also generates keys, signs and verifies, and encrypts with AEAD ciphers or RSA. `jsec/cert` parses, fingerprints and verifies X.509 certificates and makes self-signed ones. `jsec/ca` runs a small certificate authority: issue, sign CSRs, revoke, CRLs. `jsec/bio` is OpenSSL's memory buffer, for code that needs one.

```janet
(import jsec/crypto)

(def key (crypto/generate-key :ec-p256))
(def sig (crypto/sign key "message"))
(print (crypto/verify key "message" sig))
```

## Open a TLS connection directly

For protocols other than HTTP, `jsec/tls` connects, listens and upgrades plain connections (STARTTLS); `jsec/tls-stream` and `jsec/dtls-stream` are the TLS and DTLS streams underneath. `jsec/utils` reports the TLS library and its version.

```janet
(import jsec/utils)

(pp (utils/ssl-version))
```

## Work with dates and times

`os/time` and `os/date` are core. `spork/date` parses, formats and does arithmetic on dates. `spork/cron` reads cron schedules and finds the next time one fires.

```janet
(import spork/date)
(import spork/cron)

(def d (date/from-string "2026-03-01" "yyyy-MM-dd"))
(print (date/to-string (date/add d :days 30) "yyyy-MM-dd"))
(def daily (cron/parse-cron "0 9 * * *"))
(print (date/to-string (os/date (cron/next-timestamp daily (os/time))) "yyyy-MM-dd HH:mm"))
```

## Run tasks concurrently

`ev/go`, `ev/gather` and `ev/thread` are core. `spork/ev-utils` adds structured concurrency (nurseries, `pcall` and `pdag`), and `spork/channel` turns a collection into a channel.

```janet
(import spork/ev-utils)

(def results @[])
(ev-utils/pcall (fn [i] (ev/sleep 0) (array/push results (* i i))) 4)
(pp (sort results))
```

## Read input line by line

`file/lines` reads a file a line at a time, and `(file/read stdin :line)` reads one line of stdin. `spork/stream/lines` does the same for a stream, such as a socket or a process's output. `spork/getline` is the line editor of the REPL, with history and completion, for interactive prompts; `spork/rawterm` reads keys from a terminal one at a time.

```janet
(spit "lines.txt" "one\ntwo\n")
(with [f (file/open "lines.txt")]
  (each line (file/lines f) (prin "> " line)))
(os/rm "lines.txt")
```

## Send messages between programs

`spork/msg` frames messages over a stream. `spork/rpc` calls functions in another process over the network, and `spork/netrepl` serves a REPL on a socket.

## Work with binary data

`buffer/push-uint32` and its kin write numbers into a buffer, and `int/u64`, `int/s64` and `string/bytes` are core. `spork/tarray` reads numbers out of bytes: `tarray/new` copies a buffer or string (one from `slurp`, say) and views it as typed numbers, with the offset in bytes and the size and stride in elements, in the host's byte order, little-endian on every chirp target. `(doc tarray/new)` has the details. `spork/utf8` decodes and encodes UTF-8 code points.

Parse a binary header, here the 12 bytes that start a GLB file: a 4-byte magic, then the version and the total length as 32-bit little-endian numbers.

```janet
(import spork/tarray)

# In a script: (def bytes (slurp "model.glb"))
(def bytes (buffer "glTF" (buffer/push-uint32 @"" :le 2) (buffer/push-uint32 @"" :le 1024)))
(def header (tarray/new :uint32 2 1 4 bytes))   # 2 numbers from byte 4
(assert (= "glTF" (string/slice bytes 0 4)) "not a GLB file")
(printf "version %d, %d bytes" (header 0) (header 1))
```

```janet
(import spork/utf8)
(pp (utf8/decode-rune "é"))
```

## Do math, statistics and random numbers

`math/` is core. `spork/math` adds statistics, matrices and distributions, `spork/cmath` modular arithmetic on integers, and `spork/randgen` random choices and Gaussian samples. `spork/infix` writes arithmetic in the usual infix order.

```janet
(import spork/math)
(import spork/randgen)
(import spork/infix)

(print (math/median [3 1 4 1 5]))
(print (math/variance [2 4 4 4 5 5 7 9]))
(print (infix/$$ 1 + 2 * 3))
(print (randgen/rand-int 1 7))
```

## Generate values lazily

`spork/generators` builds lazy sequences as fibers: `range`, `map`, `filter`, `take`, `cycle` and more.

```janet
(import spork/generators :as gen)

(pp (seq [x :in (gen/take 3 (gen/cycle [:a :b]))] x))
```

## Format Janet source code

`spork/fmt` formats Janet code, as a string or a file in place.

```janet
(import spork/fmt)

(print (fmt/format "(defn f [x]\n(+ x 1))"))
```

## Test your code

`spork/test` has assertions that report rather than stop, suites with a summary, output capture and timing.

```janet
(import spork/test)

(test/start-suite "math")
(test/assert (= 4 (+ 2 2)) "addition")
(test/end-suite)
```
