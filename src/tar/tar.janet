# tar: list, extract and create tar archives, plain or gzipped, with nothing
# but chirp. Archives are read and written in pieces, never held whole.
#
# Reading understands ustar, pax extended headers (local and global) and GNU
# long names; writing produces ustar, adding a pax header only for what ustar
# cannot hold. Extraction refuses any entry that would land outside its
# directory, so an untrusted archive can be unpacked.

(import gzip)

(def- piece 65536)
# A function, not a value: the image is built on linux for every target.
(defn- windows? [] (truthy? (index-of (os/which) [:windows :mingw])))
# The largest number an 11-digit octal field holds.
(def- octal-max 8589934591)
# A pax or GNU long-name header larger than this is refused, not buffered.
(def- meta-max 1048576)

(defn- fail [& parts] (error (string "tar: " ;parts)))

# Sources and sinks

(defn- source
  "A function that returns the next piece of `src`, nil at its end, and one that
  releases it. A string is a path, a buffer is the archive's bytes, anything
  else is read with :read, as files and streams are."
  [src]
  (cond
    (string? src)
    (let [f (file/open src :rb)]
      (unless f
        (fail "cannot open " (describe (if (> (length src) 80) (string (string/slice src 0 80) "...") src))
              "; a string is a path, so pass an archive's bytes as a buffer"))
      [(fn [] (file/read f piece)) |(file/close f)])

    (buffer? src)
    (do
      (var at 0)
      [(fn []
         (when (< at (length src))
           (def end (min (length src) (+ at piece)))
           (def out (buffer/slice src at end))
           (set at end)
           out))
       (fn [])])

    [(fn [] (:read src piece)) (fn [])]))

(defn- ungzipped
  "`next` with gzip undone, if its data starts like gzip."
  [next]
  (def head @"")
  (var more true)
  (while (and more (< (length head) 2))
    (if-let [p (next)] (buffer/push head p) (set more false)))
  (if (and (>= (length head) 2) (= 0x1f (head 0)) (= 0x8b (head 1)))
    (let [z (gzip/decompressor)
          out @""]
      (var pending head)
      (var done false)
      (fn []
        (buffer/clear out)
        (while (and (empty? out) (not done))
          (if pending
            (do (gzip/update z pending out) (set pending (next)))
            (do (gzip/finish z) (set done true))))
        (if (empty? out) nil out)))
    (do
      (var pending (if (empty? head) nil head))
      (fn [] (if-let [p pending] (do (set pending nil) p) (next))))))

(defn- taker
  "A function returning the next `n` bytes of `next`, fewer only at its end."
  [next]
  (def buf @"")
  (var at 0)
  (var eof false)
  (fn [n]
    (while (and (not eof) (< (- (length buf) at) n))
      (when (> at 0)
        (def rest (buffer/slice buf at))
        (buffer/clear buf)
        (buffer/push buf rest)
        (set at 0))
      (if-let [p (next)] (buffer/push buf p) (set eof true)))
    (def end (min (length buf) (+ at n)))
    (def out (buffer/slice buf at end))
    (set at end)
    out))

(defn- sink
  "A function writing bytes to `dest`, and one that ends the archive there.
  A string is a path, a buffer is appended to, anything else is written with
  :write. With `level` the bytes are gzipped first."
  [dest level]
  (def [write close]
    (cond
      (string? dest)
      (let [f (file/open dest :wb)]
        (unless f (fail "cannot create " dest))
        [|(file/write f $) |(file/close f)])
      (buffer? dest) [|(buffer/push dest $) (fn [])]
      [|(:write dest $) (fn [])]))
  (if level
    (let [z (gzip/compressor level)
          out @""]
      [(fn [bytes]
         (buffer/clear out)
         (gzip/update z bytes out)
         (unless (empty? out) (write out)))
       (fn []
         (buffer/clear out)
         (write (gzip/finish z out))
         (close))])
    [write close]))

# Headers

(defn- field
  "The bytes of a header field up to its first NUL."
  [h from len]
  (def s (string/slice h from (+ from len)))
  (if-let [i (string/find "\0" s)] (string/slice s 0 i) s))

(defn- number-field
  "A numeric header field: octal digits, or GNU's base-256 when the top bit is set."
  [h from len what]
  (def b0 (h from))
  (if (not= 0 (band b0 0x80))
    (do
      (when (not= 0 (band b0 0x40)) (fail "negative " what " field"))
      (var v (band b0 0x3f))
      (for i (+ from 1) (+ from len) (set v (+ (* v 256) (h i))))
      (when (> v math/int-max) (fail what " field too large"))
      v)
    (let [s (string/trim (field h from len) " \0")]
      (cond
        (empty? s) 0
        (peg/match ~(* (some (range "07")) -1) s) (scan-number s 8)
        (fail "bad " what " field " (describe s))))))

(defn- checksum-ok? [h]
  (def want (number-field h 148 8 "checksum"))
  (var unsigned 0)
  (var signed 0)
  (for i 0 512
    (def b (if (and (>= i 148) (< i 156)) 32 (h i)))
    (+= unsigned b)
    (+= signed (if (> b 127) (- b 256) b)))
  (or (= want unsigned) (= want signed)))

(defn- pax-records
  "The key=value records of a pax header's data."
  [data]
  (def res @{})
  (var i 0)
  (while (< i (length data))
    (def sp (string/find " " data i))
    (def len (and sp (scan-number (string/slice data i sp))))
    (unless (and len (int? len) (> len (- sp i)) (<= (+ i len) (length data))
                 (= 10 (data (+ i len -1))))
      (fail "bad pax header"))
    (def rec (string/slice data (+ sp 1) (+ i len -1)))
    (def eq (string/find "=" rec))
    (unless eq (fail "bad pax record " (describe rec)))
    (put res (string/slice rec 0 eq) (string/slice rec (+ eq 1)))
    (+= i len))
  res)

(defn- pax-number [k v]
  (def n (scan-number v))
  (unless (and n (>= n 0)) (fail "bad pax " k " " (describe v)))
  n)

(defn- apply-pax
  "Override `entry`'s fields from pax records. An empty value cancels an earlier
  one, leaving the header's own."
  [entry hdr records]
  (eachp [k v] records
    (when (string/has-prefix? "GNU.sparse" k) (fail "sparse files are not supported: " (entry :name)))
    (def key (case k "path" :name "linkpath" :link "size" :size "mtime" :mtime
                     "uid" :uid "gid" :gid "uname" :uname "gname" :gname))
    (when key
      (put entry key
           (cond
             (empty? v) (hdr key)
             (in {:size true :uid true :gid true} key)
             (let [n (pax-number k v)]
               (unless (int? n) (fail "bad pax " k " " (describe v)))
               n)
             (= key :mtime) (pax-number k v)
             v)))))

(def- types
  {(chr "0") :file (chr "\0") :file (chr "7") :file (chr "1") :hardlink
   (chr "2") :symlink (chr "3") :char (chr "4") :block (chr "5") :dir
   (chr "6") :fifo})

(defn- parse-header [h]
  (unless (checksum-ok? h) (fail "header checksum mismatch; not a tar archive, or corrupt"))
  (def name (field h 0 100))
  (def prefix (field h 345 155))
  {:name (if (and (= "ustar\0" (string/slice h 257 263)) (not (empty? prefix)))
           (string prefix "/" name)
           name)
   :mode (number-field h 100 8 "mode")
   :uid (number-field h 108 8 "uid")
   :gid (number-field h 116 8 "gid")
   :size (number-field h 124 12 "size")
   :mtime (number-field h 136 12 "mtime")
   :typeflag (h 156)
   :link (field h 157 100)
   :uname (field h 265 32)
   :gname (field h 297 32)})

(defn- padding [size] (% (- 512 (% size 512)) 512))

(defn- reader
  "A function returning the next entry of the archive `take` reads, or nil after
  the last, and one reading up to n bytes of the current entry's data. Data left
  unread is skipped when the next entry is asked for."
  [take]
  (def global @{})
  (var left 0)
  (var pad 0)
  (var ended false)
  (defn skip [n]
    (var n n)
    (while (> n 0)
      (def got (length (take (min n piece))))
      (when (zero? got) (fail "truncated archive"))
      (-= n got)))
  (defn meta-data [hdr]
    (def size (hdr :size))
    (when (> size meta-max) (fail "extended header of " size " bytes is too large"))
    (def data (take size))
    (when (< (length data) size) (fail "truncated archive"))
    (skip (padding size))
    data)
  (defn read-data [n]
    (def n (min n left))
    (def out (take n))
    (when (< (length out) n) (fail "truncated archive"))
    (-= left (length out))
    out)
  (defn next-entry []
    (skip (+ left pad))
    (set left 0)
    (set pad 0)
    (var local @{})
    (var long-name nil)
    (var long-link nil)
    (var result nil)
    (while (and (not result) (not ended))
      (def h (take 512))
      (cond
        # A clean end at a block boundary is accepted without the end marker, as
        # GNU tar does; gzip has already caught a truncated download.
        (empty? h) (set ended true)
        (< (length h) 512) (fail "truncated archive")
        # Past the end marker only padding remains. It is read anyway, so gzip
        # reaches its trailer and checks it.
        (all zero? h) (do (set ended true) (while (not (empty? (take piece)))))
        (let [hdr (parse-header h)
              t (hdr :typeflag)]
          (cond
            (= t (chr "x")) (merge-into local (pax-records (meta-data hdr)))
            (= t (chr "g")) (merge-into global (pax-records (meta-data hdr)))
            (= t (chr "L")) (set long-name (let [d (meta-data hdr)] (field d 0 (length d))))
            (= t (chr "K")) (set long-link (let [d (meta-data hdr)] (field d 0 (length d))))
            (= t (chr "V")) (skip (+ (hdr :size) (padding (hdr :size))))
            (let [entry (merge hdr)]
              (when long-name (put entry :name long-name))
              (when long-link (put entry :link long-link))
              (apply-pax entry hdr global)
              (apply-pax entry hdr local)
              (def type (types t))
              (unless type
                (fail "unsupported entry type " (describe (string/from-bytes t))
                      " for " (entry :name)))
              (put entry :type
                   (if (and (= type :file) (not= t (chr "7")) (string/has-suffix? "/" (entry :name)))
                     :dir
                     type))
              (put entry :typeflag nil)
              (unless (in {:symlink true :hardlink true} (entry :type)) (put entry :link nil))
              (set left (entry :size))
              (set pad (padding (entry :size)))
              (set result (table/to-struct entry)))))))
    result)
  [next-entry read-data])

(defn- with-reader
  "Call (f next-entry read-data) on the archive `src`, releasing it afterwards."
  [src f]
  (def [next close] (source src))
  (defer (close)
    (f ;(reader (taker (ungzipped next))))))

(defn list
  ```
  The entries of the tar archive `src`, gzipped or not, in archive order. `src`
  is a path (a string), the archive's bytes (a buffer), or a file or stream to
  read. Each entry is a struct with :name, :type (:file, :dir, :symlink,
  :hardlink, :char, :block or :fifo), :size, :mode, :mtime, :uid, :gid, :uname
  and :gname, and :link for links. Names are as stored, not checked.
  ```
  [src]
  (with-reader src
    (fn [next _]
      (def res @[])
      (var e nil)
      (while (set e (next)) (array/push res e))
      res)))

# Extraction

(defn- refuse [name why] (fail "refusing " (describe name) ": " why))

(defn- parts
  "`path`'s components, without empty and . ones. Absolute paths and .. are
  refused, and on Windows so are drive letters and backslashes. Refusals name
  the entry `name`."
  [path name]
  (def what (if (= path name) "" (string "a hard link to " (describe path) " with ")))
  (when (string/has-prefix? "/" path) (refuse name (string what "an absolute path")))
  (when (and (windows?) (or (string/find "\\" path) (string/find ":" path)))
    (refuse name (string what "a backslash or colon, which Windows reads as a path")))
  (def res (filter |(not (or (empty? $) (= "." $))) (string/split "/" path)))
  (when (index-of ".." res) (refuse name (string what "a .. component")))
  res)

(defn- join [dest ps] (string/join [dest ;ps] "/"))

(defn- dir-of [path]
  (def seps (if (windows?) (string/find-all "\\" (string/replace-all "/" "\\" path))
              (string/find-all "/" path)))
  (def k (last seps))
  (when (and k (> k 0)) (string/slice path 0 k)))

(defn- mkdirs [path]
  (unless (os/stat path)
    (when-let [parent (dir-of path)] (mkdirs parent))
    (os/mkdir path)))

(defn- check-parents
  "Make sure every directory between `dest` and the entry `ps` names is a real
  directory, creating missing ones when `create`. A symlink on the way is
  refused, so nothing is written through one."
  [dest ps name create]
  (var p dest)
  (for i 0 (- (length ps) 1)
    (set p (string p "/" (ps i)))
    (case (os/lstat p :mode)
      :directory nil
      nil (if create (os/mkdir p) (refuse name "a missing directory"))
      :link (refuse name (string "a symlink on the way, " (string/join (slice ps 0 (+ i 1)) "/")))
      (refuse name (string "a non-directory on the way, " (string/join (slice ps 0 (+ i 1)) "/"))))))

(defn- clear
  "Remove what is at `path`, unless it is a directory, so an entry replaces it
  rather than writing through a link."
  [path]
  (def mode (os/lstat path :mode))
  (when (and mode (not= mode :directory)) (os/rm path)))

(defn- link-target-ok?
  "Whether the symlink target `target`, read from the directory `dir` (components
  under the destination), stays inside the destination."
  [dir target]
  (unless (or (string/has-prefix? "/" target)
              (and (windows?) (string/find ":" target)))
    (var depth (length dir))
    (var ok true)
    (each c (string/split "/" target)
      (cond
        (or (empty? c) (= "." c)) nil
        (= ".." c) (do (-- depth) (when (< depth 0) (set ok false)))
        (++ depth)))
    ok))

(defn- current-umask []
  (if (windows?) 0 (let [u (os/umask 0)] (os/umask u) u)))

(defn extract
  ```
  Extract the tar archive `src` into directory `dest`, which is created if
  missing, and return the names written, relative to `dest`. `src` is as for
  `tar/list`. Options:

  * :strip - drop this many leading components from each name; entries with no
    more are skipped, as with tar's --strip-components.

  Modes are applied less the umask, and mtimes are kept, as tar does for a
  user who is not root; owners are not. On Windows only files keep mtimes. An entry that would land outside
  `dest` is an error, and so is an entry type that cannot be extracted (devices
  and fifos, and links on Windows); entries before it stay extracted.
  ```
  [src dest &opt opts]
  (def strip (get opts :strip 0))
  (unless (and (int? strip) (>= strip 0)) (fail ":strip must be a non-negative integer"))
  (def dest (if (and (> (length dest) 1) (string/has-suffix? "/" dest))
              (string/slice dest 0 -2)
              dest))
  (mkdirs dest)
  (def mask (bnot (current-umask)))
  (def done @[])
  (def dirs @[])
  (with-reader src
    (fn [next read-data]
      (var e nil)
      (while (set e (next))
        (def name (e :name))
        (def comps (parts name name))
        (when (> (length comps) strip)
          (def ps (slice comps strip))
          (def rel (string/join ps "/"))
          (def path (join dest ps))
          (def mode (band (e :mode) 8r777 mask))
          (check-parents dest ps name true)
          (case (e :type)
            :dir
            (do
              (clear path)
              (unless (os/stat path) (os/mkdir path))
              (array/push dirs [path mode (e :mtime)]))

            :file
            (do
              (clear path)
              (def f (file/open path :wb))
              (unless f (fail "cannot create " path))
              (defer (file/close f)
                (var p (read-data piece))
                (while (not (empty? p))
                  (file/write f p)
                  (set p (read-data piece))))
              (unless (windows?) (os/chmod path mode))
              (os/touch path (math/floor (e :mtime)) (math/floor (e :mtime))))

            :symlink
            (do
              (when (windows?) (fail "cannot create symlink " name " on Windows"))
              (unless (link-target-ok? (slice ps 0 -2) (e :link))
                (refuse name (string "a symlink to " (describe (e :link)) ", outside the directory")))
              (clear path)
              (os/symlink (e :link) path))

            :hardlink
            (do
              (def tall (parts (e :link) name))
              (when (<= (length tall) strip) (refuse name "a hard link to a stripped name"))
              (def tps (slice tall strip))
              (when (deep= tps ps) (refuse name "a hard link to itself"))
              (check-parents dest tps name false)
              (def target (join dest tps))
              (unless (= :file (os/lstat target :mode))
                (refuse name (string "a hard link to " (describe (e :link)) ", not an extracted file")))
              (clear path)
              (if (windows?)
                (spit path (slurp target))
                (os/link target path)))

            (fail "cannot extract " name ", a " (e :type) " entry"))
          (array/push done rel)))))
  # Directories last, deepest first, so their files can be written and do not
  # move their mtimes. Windows' utime cannot open a directory, so there they
  # keep the time of extraction.
  (unless (windows?)
    (each [path mode mtime] (reverse dirs)
      (os/chmod path mode)
      (os/touch path (math/floor mtime) (math/floor mtime))))
  done)

# Creation

(defn- octal-field [h off width n]
  (def s (string/format "%o" n))
  (buffer/blit h (string (string/repeat "0" (- width 1 (length s))) s) off))

(defn- split-name
  "`name` as ustar's [prefix name], or nil if it does not fit."
  [name]
  (if (<= (length name) 100)
    ["" name]
    (do
      (var res nil)
      (loop [i :in (reverse (string/find-all "/" name))
             :until res
             :when (and (> i 0) (<= i 155) (<= (- (length name) i 1) 100)
                        (> (- (length name) i 1) 0))]
        (set res [(string/slice name 0 i) (string/slice name (+ i 1))]))
      res)))

(defn- pax-record [k v]
  (def body (string " " k "=" v "\n"))
  (var n (+ (length body) 1))
  (while (not= n (+ (length body) (length (string n)))) (++ n))
  (string n body))

(defn- ustar-header [name prefix typeflag size mode mtime link]
  (def h (buffer/new-filled 512 0))
  (buffer/blit h name 0)
  (octal-field h 100 8 mode)
  (octal-field h 108 8 0)
  (octal-field h 116 8 0)
  (octal-field h 124 12 size)
  (octal-field h 136 12 mtime)
  (buffer/blit h "        " 148)
  (put h 156 typeflag)
  (buffer/blit h link 157)
  (buffer/blit h "ustar\0" 257)
  (buffer/blit h "00" 263)
  (buffer/blit h prefix 345)
  (var sum 0)
  (each b h (+= sum b))
  (buffer/blit h (string/format "%06o\0 " sum) 148)
  h)

(defn- header
  "The header blocks for one entry: ustar, preceded by a pax header for what
  ustar cannot hold."
  [name typeflag size mode mtime link]
  (def split (split-name name))
  (def records @[])
  (unless split (array/push records (pax-record "path" name)))
  (when (> (length link) 100) (array/push records (pax-record "linkpath" link)))
  (when (> size octal-max) (array/push records (pax-record "size" (string size))))
  (def mtime (math/floor mtime))
  (def mtime-ok (and (>= mtime 0) (<= mtime octal-max)))
  (unless mtime-ok (array/push records (pax-record "mtime" (string mtime))))
  (def [prefix short] (or split ["" (string/slice name 0 100)]))
  (def out @"")
  (unless (empty? records)
    (def data (string/join records))
    (def base (string/slice short (max 0 (- (length short) 89))))
    (buffer/push out (ustar-header (string "PaxHeaders/" base) "" (chr "x")
                                   (length data) 8r644 (if mtime-ok mtime 0) ""))
    (buffer/push out data (buffer/new-filled (padding (length data)) 0)))
  (buffer/push out (ustar-header short prefix typeflag (if (> size octal-max) 0 size)
                                 mode (if mtime-ok mtime 0) (string/slice link 0 (min 100 (length link)))))
  out)

(defn- archive-name
  "`path` as stored: components joined by /, with empty and . ones dropped.
  Absolute paths and .. are refused, so an archive never holds what extraction
  would refuse."
  [path]
  (def ps (filter |(not (or (empty? $) (= "." $)))
                  (string/split "/" (if (windows?) (string/replace-all "\\" "/" path) path))))
  (when (or (string/has-prefix? "/" path) (index-of ".." ps)
            (and (windows?) (string/find ":" path)))
    (fail "paths to add must be relative and inside :dir, got " (describe path)))
  (string/join ps "/"))

(defn create
  ```
  Write a tar archive of `paths` to `dest` and return `dest`. `dest` is a path
  (a string), a buffer to append to, or a file or stream to write to. Each path
  is relative to :dir and directories are added with everything under them, in
  sorted order. Files, directories and symlinks are stored; anything else is an
  error. Owners are stored as 0 and unnamed. Options:

  * :dir - where `paths` are found, default "."
  * :gzip - gzip the archive; true when `dest` is a path ending .gz or .tgz
  * :level - the gzip level, 0 to 9, default 6
  ```
  [dest paths &opt opts]
  (def dir (get opts :dir "."))
  (def gz (get opts :gzip (and (string? dest)
                               (or (string/has-suffix? ".gz" dest) (string/has-suffix? ".tgz" dest)))))
  (def [emit close] (sink dest (when gz (get opts :level 6))))
  (defn add [name]
    (def path (if (empty? name) dir (string dir "/" name)))
    (def st (os/lstat path))
    (unless st (fail "cannot add " path ", it does not exist"))
    (def mode (band (st :int-permissions) 8r7777))
    (case (st :mode)
      :directory
      (do
        (unless (empty? name)
          (emit (header (string name "/") (chr "5") 0 mode (st :modified) "")))
        (each child (sort (os/dir path))
          (add (if (empty? name) child (string name "/" child)))))

      :file
      (do
        (def size (st :size))
        (emit (header name (chr "0") size mode (st :modified) ""))
        (def f (file/open path :rb))
        (unless f (fail "cannot open " path))
        (var left size)
        (defer (file/close f)
          (while (> left 0)
            (def p (file/read f (min left piece)))
            (unless p (fail path " shrank while it was read"))
            (emit p)
            (-= left (length p))))
        (emit (buffer/new-filled (padding size) 0)))

      :link
      (emit (header name (chr "2") 0 mode (st :modified) (os/readlink path)))

      (fail "cannot add " path ", a " (st :mode))))
  (defer (close)
    (each p paths (add (archive-name p)))
    (emit (buffer/new-filled 1024 0)))
  dest)
