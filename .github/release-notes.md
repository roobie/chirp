chirp @VERSION@ is an unofficial build of [Janet](https://janet-lang.org). It is not a Janet release and is not made by Janet's maintainers.

It bundles TLS (jsec with a static OpenSSL 3), spork, spork-https, SQLite (sqlite3, with FTS5), TOML (tomlin) YAML (yaml, on libyaml), Perl-style regular expressions (pcre2, on PCRE2), Markdown to HTML (md4c), HTML parsing with CSS selectors (lexbor) and an insertion-ordered map (omap) that json and yaml decode to and encode from, in one binary per target, plus offline help (`chirp help`). Each target's third-party license texts are in its `NOTICES-<target>.txt`.

Check a download before you run it, as described under "Verifying a download" in the [README](https://github.com/roobie/chirp#verifying-a-download):

```sh
sha256sum -c SHA256SUMS --ignore-missing
gh attestation verify <file> --repo roobie/chirp
```

`SHA256SUMS.sig` is an Ed25519 signature of `SHA256SUMS`. `chirp self-update` checks it with the key built into chirp before installing a newer release.

On Windows, HTTPS needs `SSL_CERT_FILE` pointing at a PEM CA bundle for now.
