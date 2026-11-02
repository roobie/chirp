# gzip and tar archives

Two modules handle `.gz` data and tar archives with nothing else installed, so a script can fetch and unpack a release on a host without `tar`, Windows included. Both were added in chirp 0.7.0.

## gzip

`gzip/compress` and `gzip/decompress` work on whole buffers. The data is gzip (RFC 1952), what `gzip` and HTTP's `Content-Encoding: gzip` use; `spork/zip`'s `zip/compress` makes the zlib format, which `gzip -d` does not read.

```janet
(import gzip)

(spit "notes.txt.gz" (gzip/compress (slurp "notes.txt")))
(print (gzip/decompress (slurp "notes.txt.gz")))
```

A `.gz` file of several members, as `cat a.gz b.gz` makes, decompresses to their concatenation, as with `gzip -d`. A bad checksum, a truncated member or bytes after the last member is an error, never short output. `gzip/compress` takes a level from 0 to 9 (default 6), and writes no name or time into the header, so the same input always gives the same bytes.

Data that arrives in pieces, or is too large to hold twice, goes through a compressor or decompressor instead:

```janet
(def z (gzip/decompressor))
(with [f (file/open "big.log.gz" :rb)]
  (while (def piece (file/read f 65536))
    (prin (gzip/update z piece)))  # what this piece completes, maybe nothing yet
  (gzip/finish z))                 # an error if the data stopped inside a member
```

`gzip/compressor` is the same the other way: `gzip/update` for each piece, then `gzip/finish` for the rest of the output and the trailer.

## tar

`tar/list`, `tar/extract` and `tar/create` read and write tar archives, gzipped or not. Reading tells gzip from its first bytes; writing gzips when the file name ends `.gz` or `.tgz`, or when `:gzip` says so. Archives are read and written in pieces, so a large one is never held in memory.

```janet
(import tar)

(tar/extract "chirp-src.tar.gz" "chirp-src" {:strip 1})  # like tar -xzf ... --strip-components=1
(map |($ :name) (tar/list "chirp-src.tar.gz"))
(tar/create "backup.tar.gz" ["notes" "config.toml"] {:dir (os/getenv "HOME")})
```

The source of `tar/list` and `tar/extract` is a path (a string), the archive's bytes (a buffer), or an open file or stream. An HTTP body is a buffer, so a download unpacks without a temporary file; bytes held in a string must be passed as `(buffer s)`, because a string is a path. `tar/create` writes to a path, appends to a buffer, or writes to a file or stream, and adds directories with everything under them, in sorted order.

Reading understands ustar, pax headers and GNU long names, which covers what GNU tar, bsdtar, Python and Go write. Writing produces ustar, with a pax header only for a name, link or size that ustar cannot hold, and stores owners as 0. Files, directories and symlinks are stored; hard links are stored as copies.

## Untrusted archives

`tar/extract` refuses any entry that would land outside its directory, so an archive from the network can be unpacked as it is. It is an error when an entry:

- has an absolute name, or a `..` component;
- is a symlink whose target is absolute, or leads out of the directory;
- would be written through a symlink, even one that points inside;
- is a hard link to a name that is not a file it already extracted.

An earlier file or symlink at an entry's path is replaced, never written through. Entries before a refused one stay extracted. Devices and fifos cannot be extracted, and neither can links on Windows, where Janet cannot make them.

Modes are applied less the umask and modification times are kept, as `tar` does for a user who is not root. On Windows only files keep their times.
