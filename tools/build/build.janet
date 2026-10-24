# Build chirp. Usage: janet build.janet <outdir> <repo>
# Run by tools/build/container.sh with the janet built from the pinned source.
# Pins, options and the native module list live in the .jdn data files.

(def [out repo] (let [a (dyn *args*)] [(a (- (length a) 2)) (last a)]))
(def janet-exe (os/realpath (dyn *executable*)))
(os/cd out)
(def abs-out (os/cwd))
(def jobs (scan-number (os/getenv "CHIRP_JOBS" "4")))

(defn- load-data [path] (parse (slurp (string repo "/" path))))
(def pins (load-data "pins.jdn"))
(def config (load-data "tools/build/config.jdn"))
(def natives (load-data "tools/build/natives.jdn"))
(def notices (load-data "tools/build/notices.jdn"))

(def target-name (keyword (os/getenv "CHIRP_TARGET" "")))
(def target
  (or (get-in config [:targets target-name])
      (errorf "CHIRP_TARGET %q is unset or unknown; valid targets: %s"
              (os/getenv "CHIRP_TARGET" "")
              (string/join (map string (sorted (keys (config :targets)))) ", "))))

(defn- mkdirs [path]
  (var acc (if (string/has-prefix? "/" path) "/" ""))
  (each seg (string/split "/" path)
    (unless (empty? seg)
      (set acc (if (empty? acc) seg (string acc "/" seg)))
      (os/mkdir acc))))

(defn- run [& cmd] (os/execute cmd :px))

(defn- capture [& cmd]
  (def p (os/spawn cmd :px {:out :pipe}))
  (def o (ev/read (p :out) :all))
  (os/proc-wait p)
  (string/trim (or o "")))

(defmacro- in-dir [dir & body]
  ~(let [back (os/cwd)]
     (os/cd ,dir)
     (defer (os/cd back) ,;body)))

(defn- fetch [name]
  (def {:url url :commit commit} (pins name))
  (def dir (string "src/" name))
  (unless (os/stat (string dir "/.git"))
    (mkdirs dir)
    (run "git" "init" "-q" dir)
    (run "git" "-C" dir "remote" "add" "origin" url))
  (unless (= commit (try (capture "git" "-C" dir "rev-parse" "HEAD") ([_] nil)))
    (run "git" "-C" dir "fetch" "-q" "--depth" "1" "origin" commit)
    (run "git" "-C" dir "checkout" "-q" "--force" "--detach" "FETCH_HEAD"))
  (assert (= commit (capture "git" "-C" dir "rev-parse" "HEAD")) "pin mismatch"))

(each name [:janet :spork :jsec :spork-https :openssl] (fetch name))

# Patches to a pinned checkout, applied once and failing loudly if they do not
# apply.
(defn- patch [name file]
  (def dir (string "src/" name))
  (def path (string repo "/tools/build/patches/" file))
  (defn applies? [& flags]
    (def p (os/spawn ["git" "-C" dir "apply" "--check" ;flags path] :p {:err :pipe}))
    (ev/read (p :err) :all)
    (zero? (os/proc-wait p)))
  (cond
    (applies?) (do (run "git" "-C" dir "apply" path) (print "applied " file))
    (applies? "-R") (print "already applied " file)
    (errorf "patch %s fits neither the pinned nor the patched %s" file name)))
# spork numbers each native's image prefix from a process-global counter, which
# makes the image differ between otherwise identical builds.
(patch :spork "spork-deterministic-native-prefixes.patch")
# On windows, Janet writes a byte count just past the OVERLAPPED in jsec's
# accept state, wiping the accepted socket, so every TLS server dies on its
# first connection.
(patch :jsec "jsec-iocp-accept-state-padding.patch")

# Everything the image build loads is built for the build machine; everything
# linked into the executable is built again by zig for the target.
(def build-machine (config :build-machine))

# Pinned zig, checked against the tarball hash before it is unpacked. It goes on
# PATH by name so no build path leaks into flags that get recorded in binaries.
(defn- setup-zig []
  (def {:version version :url url :sha256 sha} (pins :zig))
  (def tarball (string abs-out "/cache/zig-" version ".tar.xz"))
  (def dir (string abs-out "/cache/zig-" version))
  (unless (os/stat (string dir "/.done"))
    (mkdirs (string abs-out "/cache"))
    (unless (os/stat tarball) (run "curl" "-fsSL" "-o" tarball url))
    (def got (get (string/split " " (capture "sha256sum" tarball)) 0))
    (unless (= got sha)
      (os/rm tarball)
      (errorf "zig tarball sha256 %s does not match pin %s" got sha))
    (run "rm" "-rf" dir)
    (mkdirs dir)
    (run "tar" "-xJf" tarball "-C" dir "--strip-components=1")
    (spit (string dir "/.done") ""))
  (os/setenv "PATH" (string dir ":" (os/getenv "PATH")))
  (os/setenv "ZIG_GLOBAL_CACHE_DIR" (string abs-out "/cache/zig-global"))
  (os/setenv "ZIG_LOCAL_CACHE_DIR" (string abs-out "/cache/zig-local"))
  (print "zig " (capture "zig" "version") " (sha256 " sha ")")
  dir)

(def zig-cc ["zig" "cc" "-target" (target :triple)])
(def zig-dir (setup-zig))
# OpenSSL builds in its source tree, so each target gets its own copy.
(def- openssl-copy (string "src/openssl-" target-name))
(unless (os/stat openssl-copy) (run "cp" "-a" "src/openssl" openssl-copy))

# Commit time of the janet pin stands in for every embedded date.
(os/setenv "SOURCE_DATE_EPOCH" (capture "git" "-C" "src/janet" "log" "-1" "--format=%ct"))

(def prefix-map (string "-ffile-prefix-map=" abs-out "=."))

# OpenSSL, cached by pin. Installed under DESTDIR so build paths stay out of it.
# Returns [include-root lib-paths].
(def ossl (config :openssl))
(defn- build-openssl [src-dir stage t]
  (def root (string stage (ossl :prefix)))
  (unless (os/stat (string stage "/.done"))
    (def cc-env (when (t :triple)
                  {"CC" (string/join zig-cc " ") "AR" "zig ar" "RANLIB" "zig ranlib"}))
    (def saved (tabseq [k :keys (or cc-env {})] k (or (os/getenv k) false)))
    (eachp [k v] (or cc-env {}) (os/setenv k v))
    (defer (eachp [k v] saved (os/setenv k (when v v)))
      (in-dir src-dir
        (run (if (t :openssl-target) "./Configure" "./config")
             ;(if-let [ot (t :openssl-target)] [ot] [])
             ;(ossl :configure) ;(get t :openssl-flags [])
             (string "--prefix=" (ossl :prefix)))
        (run "make" (string "-j" jobs) ;(ossl :make))
        (run "make" ;(ossl :install) (string "DESTDIR=" stage))
        # Only the installed libraries are used from here on.
        (run "make" "clean")))
    (spit (string stage "/.done") ""))
  [root (map |(string root "/lib/" $) (ossl :libs))])

(def ossl-commit (string/slice (get-in pins [:openssl :commit]) 0 12))
(def ossl-stage (string abs-out "/cache/openssl-" ossl-commit))
(def [ossl-root ossl-libs] (build-openssl "src/openssl" ossl-stage build-machine))

# Staged janet prefix for spork/cc.
(def janet-prefix (string abs-out "/prefix"))
(mkdirs "prefix/include")
(mkdirs "prefix/lib")
(run "cp" "src/janet/build/janet.h" "prefix/include/janet.h")
(run "cp" "src/janet/build/libjanet.a" "prefix/lib/libjanet.a")

# Janet source and native modules, as seen by the image-building janet.
# Relative paths keep recorded source locations identical across out dirs.
(each name (config :janet-sources)
  (array/push module/paths [(string "src/" name "/:all:.janet") :source]))
(array/push module/paths ["modpath/:all:.so" :native])

(import spork/build-rules)
(import spork/cc)
(import spork/declare-cc)
(import spork/sh)
(import spork/path)

(defn- scan-c [p]
  (case (os/stat p :mode)
    :file @[p]
    :directory (let [r @[]]
                 (each e (sorted (os/dir p))
                   (def sub (string p "/" e))
                   (when (or (string/has-suffix? ".c" sub)
                             (= :directory (os/stat sub :mode)))
                     (array/concat r (scan-c sub))))
                 r)
    (errorf "missing source %s" p)))

(defn- native-sources [n]
  (def skip (tabseq [s :in (get n :skip [])] s true))
  (def seen @{})
  (def res @[])
  (each entry (n :sources)
    (each s (scan-c entry)
      (unless (or (skip s) (seen s))
        (put seen s true)
        (array/push res s))))
  res)

(defn- build-native [n]
  (def {:name name} n)
  (def root (string abs-out "/obj/" (string/replace-all "/" "_" name)))
  (def rules @{})
  (def ossl? (n :openssl))
  (def targets
    (in-dir (string abs-out "/src/" (string (n :pin)))
      (with-dyns [cc/*rules* rules
                  cc/*build-type* :release
                  cc/*janet-prefix* janet-prefix
                  declare-cc/*build-root* root]
        (sh/create-dirs (string root "/release/static"))
        (def declared
          (declare-cc/declare-native
            :name name
            :source (native-sources n)
            :defines (get n :defines {})
            :headers (get n :headers [])
            :cflags [prefix-map ;(if ossl? [(string "-I" ossl-root "/include")] [])]
            :static-libs (if ossl? ossl-libs)
            :use-rpath false))
        (build-rules/build-run rules "build")
        declared)))
  (def meta (with-dyns [cc/*build-dir* (string root "/release")]
              (cc/out-path name ".meta.janet")))
  (def dest (string "modpath/" name))
  (sh/create-dirs-to dest)
  (sh/copy (targets :native) (string dest ".so"))
  (sh/copy (targets :static) (string dest ".a"))
  (sh/copy meta (string dest ".meta.janet")))

(each n natives (build-native n))

# The same natives and janet again, compiled by zig for the target. The static
# entry point of each native is read from the metadata the native build wrote,
# so both builds agree on the symbol names.
(def tgt-root (string abs-out "/obj-" target-name))
(def tgt-cflags
  [prefix-map ;(get target :cflags []) (string "-I" janet-prefix "/include")])

(defn- zig [& args] (run ;zig-cc ;args))

(defn- flat [p] (string/replace-all "/" "___" p))

(defn- build-native-cross [n tgt-ossl-root]
  (def {:name name} n)
  (def meta (eval-string (slurp (string "modpath/" name ".meta.janet"))))
  (def dir (string tgt-root "/" (flat name)))
  (mkdirs dir)
  (def defs
    (sort (seq [[k v] :pairs (merge {"JANET_ENTRY_NAME" (meta :static-entry)
                                     "JANET_BUILD_TYPE" "release"}
                                    (get target :defines {})
                                    (get n :defines {}))]
            (if (= v true) (string "-D" k) (string "-D" k "=" v)))))
  (def objs
    (in-dir (string abs-out "/src/" (string (n :pin)))
      (seq [s :in (native-sources n)]
        (def o (string dir "/" (flat s) ".o"))
        (zig ;tgt-cflags ;(if (n :openssl) [(string "-I" tgt-ossl-root "/include")] [])
             ;defs "-c" s "-o" o)
        o)))
  (def lib (string dir "/" (flat name) ".a"))
  (when (os/stat lib) (os/rm lib))
  (run "zig" "ar" "rcs" lib ;objs)
  lib)

# zig's linker has no switch for a fixed COFF TimeDateStamp and fills it with a
# value that differs per build, so zero it: DOS header e_lfanew at 0x3c, then
# the signature (4 bytes), machine (2), section count (2), then the stamp.
(defn- zero-pe-timestamp [path]
  (def b (buffer (slurp path)))
  (def pe (+ (get b 0x3c) (* 256 (get b 0x3d)) (* 65536 (get b 0x3e))))
  (assert (= "PE\0\0" (string (buffer/slice b pe (+ pe 4)))) "not a PE file")
  (for i (+ pe 8) (+ pe 12) (put b i 0))
  (spit path b))

(defn- cross-link [image-c tgt-ossl-libs tgt-ossl-root]
  (def libs (map |(build-native-cross $ tgt-ossl-root) natives))
  # The amalgamation produced by the native janet build, compiled for the target.
  (def janet-o (string tgt-root "/janet.o"))
  (zig ;tgt-cflags (string "-DJANET_BUILD=\"" janet/build "\"")
       "-c" "src/janet/build/c/janet.c" "-o" janet-o)
  (def image-o (string tgt-root "/image.o"))
  (zig ;tgt-cflags "-c" image-c "-o" image-o)
  (def out-exe-name (string ((config :exe) :name) (get target :exe-suffix "")))
  (def out-exe (string "bin/" out-exe-name))
  (mkdirs "bin")
  (zig ;(get target :cflags []) "-o" out-exe image-o janet-o ;libs ;tgt-ossl-libs
       ;(get target :lflags []) ;(get target :libs []))
  # The linker also writes an import library for the exe next to it.
  (each f (os/dir "bin") (unless (= f out-exe-name) (os/rm (string "bin/" f))))
  (when (= (target :format) :pe) (zero-pe-timestamp out-exe)))

# The image is written by a fresh janet, so its gensym names do not depend on
# this script (see image.janet). It leaves the C source at a fixed path.
(run janet-exe (string repo "/tools/build/image.janet") abs-out repo ;ossl-libs)
(def image-c (string abs-out "/obj/exe/release/" ((config :exe) :name) ".c"))
(assert (os/stat image-c) "image.janet wrote no C source")

(def tgt-stage (string abs-out "/cache/openssl-" ossl-commit "-" target-name))
(def [tgt-ossl-root tgt-ossl-libs]
  (build-openssl (string "src/openssl-" target-name) tgt-stage target))
(cross-link image-c tgt-ossl-libs tgt-ossl-root)

# Everything linked into the executable has to ship its license text. Only
# file contents and config data go in, so the file is the same in any directory.
(defn- notice-section [{:title title :root root :path path :pin pin :url url}]
  (def base (case root
              :repo repo
              :zig zig-dir
              (string "src/" root)))
  # Some upstream files use CRLF; the output is LF whatever the source was.
  (def text (string/replace-all "\r\n" "\n" (slurp (string base "/" path))))
  (def link (or url
                (when-let [p (pins (or pin root))
                           u (p :url)]
                  (if (string/has-suffix? ".git" u)
                    (string/slice u 0 (- (length u) 4))
                    u))))
  (string (string/repeat "=" 78) "\n" title "\n"
          (if link (string link "\n") "") "\n"
          text (if (string/has-suffix? "\n" text) "" "\n") "\n"))

(spit "bin/NOTICES.txt"
      (string/join
        (seq [n :in notices
              :when (or (not (n :targets)) (index-of target-name (n :targets)))]
          (notice-section n))
        ""))
