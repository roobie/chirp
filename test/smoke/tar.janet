# tar is bundled: archives are listed, extracted and created with nothing else
# installed, and extraction keeps an untrusted archive inside its directory.
(import tar)
(import gzip)
(import spork/base64)
(import spork/sh)

(def- windows? (truthy? (index-of (os/which) [:windows :mingw])))

(defn- tmpdir [tag]
  (def d (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") (os/cwd))
                 "/chirp-smoke-" tag "-" (os/time) "-" (math/floor (* 1e6 (math/random)))))
  (sh/create-dirs d)
  d)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

(def- long-name (string "d/" (string/repeat "n" 110) ".txt"))

# GNU tar's output for the same tree, in its gnu format (a GNU long name) and
# in pax (a pax path): d/, d/a.txt ("one\n"), d/l -> a.txt and long-name
# ("long\n"), owned by 0/0, mtime 2024-01-02T03:04:05Z, gzipped with -9n.
(def- gnu-tgz (buffer (base64/decode "H4sIAAAAAAACA+3WQQrCMBAF0Fl7ipwgadrJzNYD9BKFioglBa3g8Y3dtaDiIkHsf5vporuf+UzvKLsqUQ3zTNZz/vYcmEWF+fmf1J7JBCrgdp26izG0Ub3r7HSfsucvwm/y51X+6kXJVMg/uzEedgS03f0fCvW/ftH/2rCQqfNX0+b33zrr9u0Yj+0pnnP2P7/ufy9h8Rbm1xLItOj/Avsfiyqw0fBj+X++/8Ky/5umTgP3XwFDqn4cgAAAAAAAAAAAAAAAAP/jAZybzXcAKAAA")))
(def- pax-tgz (buffer (base64/decode "H4sIAAAAAAACA+2XQU7DMBBFvc4pcoJkbI896aJ7llzBIhEghRS1QcrxMWWTBpWKxYRC/9vYiiM50uj9yVT1fZruutR2+0PdGhUoE5mPa2a5Egkby4E5Sn4tGLKUt6aczAq8Hca0z59ibhNPZRqfX7qtlY0P0timqZznjbBnV+TTh6+nlE+djYUBf5621r/jqLiE8/7n/Yn/FF1gUwb4v0L9Z/mfqnEaryH/rRdC/iP/gb7/StIv/Y/f+E8L/0mcy/9/BP/V2Q0dPL5p/2f9v7+a+S/EgP6P/g/0/e/V7/ic/+QH858wRVM6/V8TzH/z/B90uJT/Ttxp/b23wSP/18C6WL6m8WnbalX/DB9qF+g+v++/fqkvz39h6b/PjzD/rUC/Gx6hEgAAAAAAAAD8f94BfoqxwgAoAAA=")))

(defn- octets
  "A tar header block: name, typeflag, link and size; ustar, checksummed."
  [name typeflag &opt link size]
  (def h (buffer/new-filled 512 0))
  (buffer/blit h name 0)
  (buffer/blit h "0000644\0" 100)
  (buffer/blit h (string/format "%011o\0" (or size 0)) 124)
  (buffer/blit h "00000000000\0" 136)
  (buffer/blit h "        " 148)
  (put h 156 (typeflag 0))
  (when link (buffer/blit h link 157))
  (buffer/blit h "ustar\x0000" 257)
  (var sum 0)
  (each b h (+= sum b))
  (buffer/blit h (string/format "%06o\0 " sum) 148)
  h)

(defn- archive
  "A plain tar of [name typeflag link-or-data] entries."
  [& entries]
  (def out @"")
  (each [name t x] entries
    (if (= t "0")
      (buffer/push out (octets name t nil (length x)) x
                   (buffer/new-filled (% (- 512 (% (length x) 512)) 512) 0))
      (buffer/push out (octets name t x))))
  (buffer/push out (buffer/new-filled 1024 0)))

(defn main [&]
  (def tmp (tmpdir "tar"))
  (defer (sh/rm tmp)
    # Reading GNU tar's archives, from bytes and from a file.
    (each [what tgz] [["gnu" gnu-tgz] ["pax" pax-tgz]]
      (def es (tar/list tgz))
      (assert (deep= @["d/" "d/a.txt" "d/l" long-name] (map |($ :name) es)) (string what " names"))
      (assert (deep= @[:dir :file :symlink :file] (map |($ :type) es)) (string what " types"))
      (assert (= "a.txt" ((es 2) :link)) (string what " link"))
      (assert (= 1704164645 ((es 1) :mtime)) (string what " mtime"))
      (def f (string tmp "/" what ".tgz"))
      (spit f tgz)
      (assert (deep= es (tar/list f)) (string what " from a file"))
      (def dest (string tmp "/x-" what))
      (if windows?
        (fails |(tar/extract f dest) "symlink")
        (do
          (assert (deep= @["a.txt" "l" (string/slice long-name 2)] (tar/extract f dest {:strip 1}))
                  (string what " extracted names"))
          (assert (= "one\n" (string (slurp (string dest "/a.txt")))) (string what " content"))
          (assert (= "long\n" (string (slurp (string dest "/" (string/slice long-name 2))))) (string what " long name"))
          (assert (= :link (os/lstat (string dest "/l") :mode)) (string what " symlink"))
          (assert (= 1704164645 (os/stat (string dest "/a.txt") :modified)) (string what " mtime kept")))))

    # Creating: plain or gzipped, read back by us and by the system's tar.
    (def src (string tmp "/src"))
    # A 101-byte name cannot be split into ustar's prefix and name, so it needs
    # pax, and the whole path stays under Windows' 260-character limit.
    (def deep (string "sub/" (string/repeat "s" 20) "/" (string/repeat "f" 101)))
    (sh/create-dirs (string src "/sub/" (string/repeat "s" 20)))
    (def big (string/repeat "0123456789" 20000))
    (spit (string src "/big.txt") big)
    (spit (string src "/" deep) "deep")
    (def out (string tmp "/out.tar.gz"))
    (assert (= out (tar/create out ["."] {:dir src})) "create returns dest")
    (assert (= "\x1f\x8b" (string/slice (slurp out) 0 2)) ".tar.gz is gzipped")
    (def mem (tar/create @"" ["big.txt" "sub"] {:dir src}))
    (assert (not= "\x1f\x8b" (string/slice mem 0 2)) "a buffer is plain by default")
    (assert (string/find "PaxHeaders/" mem) "a long name gets a pax header")
    (assert (deep= (map |($ :name) (tar/list out)) (map |($ :name) (tar/list mem))) "same entries")
    (def back (string tmp "/back"))
    (tar/extract out back)
    (assert (= big (string (slurp (string back "/big.txt")))) "round trip")
    (assert (= "deep" (string (slurp (string back "/" deep))))
            "a pax long name round trip")
    (assert (deep= (slurp out) (do (tar/create out ["."] {:dir src}) (slurp out))) "same tree, same bytes")
    (fails |(tar/create @"" ["../x"] {:dir src}) "relative and inside")
    (def [found sys] (protect
                       (def p (os/spawn ["tar" "-tzf" out] :p {:out :pipe}))
                       (def listing (ev/read (p :out) :all))
                       [(os/proc-wait p) listing]))
    (when found
      (assert (= 0 (sys 0)) "system tar rejects our archive")
      (assert (string/find deep (sys 1)) "system tar reads the pax name"))

    # Untrusted archives: each is refused, and nothing lands outside.
    (def jail (string tmp "/jail"))
    (each [what tarball needle]
      [["absolute" (archive ["/abs.txt" "0" "x"]) "absolute path"]
       ["dot-dot" (archive ["a/../../up.txt" "0" "x"]) ".. component"]
       ["symlink out" (archive ["l" "2" "../up"]) "outside the directory"]
       ["absolute symlink" (archive ["l" "2" "/etc"]) "outside the directory"]
       ["through a symlink" (archive ["d" "2" "."] ["d/x.txt" "0" "x"]) "a symlink on the way"]
       ["hard link out" (archive ["h" "1" "../up.txt"]) ".. component"]
       ["hard link to a symlink" (archive ["t" "0" "x"] ["s" "2" "t"] ["h" "1" "s"]) "not an extracted file"]
       ["device" (archive ["c" "3"]) "cannot extract"]]
      (def gz (gzip/compress tarball))
      (def [ok err] (protect (tar/extract gz jail)))
      (assert (not ok) (string what " was extracted"))
      (assert (or (string/find needle (string err))
                  (and windows? (string/find "symlink" (string err))))
              (string what ": " err))
      (assert (not (os/stat (string tmp "/up.txt"))) (string what " escaped")))

    # A hard link to an extracted file shares its content (a copy on Windows).
    (def hard (string tmp "/hard"))
    (tar/extract (archive ["t.txt" "0" "x"] ["h.txt" "1" "t.txt"]) hard)
    (assert (= "x" (string (slurp (string hard "/h.txt")))) "a hard link")

    # A symlink inside the directory is fine, and a later entry replaces it
    # instead of writing through it.
    (unless windows?
      (def ok-dir (string tmp "/ok"))
      (tar/extract (archive ["a/b.txt" "0" "x"] ["a/l" "2" "../a/b.txt"] ["r" "2" "a/b.txt"] ["r" "0" "new"]) ok-dir)
      (assert (= "x" (string (slurp (string ok-dir "/a/l")))) "an inside symlink")
      (assert (= :file (os/lstat (string ok-dir "/r") :mode)) "a file replaces a symlink")
      (assert (= "x" (string (slurp (string ok-dir "/a/b.txt")))) "the link's target is untouched"))

    # Damage is an error.
    (fails |(tar/list (buffer/slice gnu-tgz 0 -9)) "truncated")
    (def plain (gzip/decompress gnu-tgz))
    (fails |(tar/list (buffer/slice plain 0 700)) "truncated")
    (def bad (buffer plain))
    (put bad 0 (chr "X"))
    (fails |(tar/list bad) "checksum")
    (print "ok tar" (if found ", read by system tar" ", no system tar"))))
