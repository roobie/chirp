# Build chirp. Usage: janet build.janet <outdir> <repo>
# Run by tools/build/linux.sh with the janet built from the pinned source.
# Pins, options and the native module list live in the .jdn data files.

(def [out repo] (let [a (dyn *args*)] [(a (- (length a) 2)) (last a)]))
(os/cd out)
(def abs-out (os/cwd))
(def jobs (scan-number (os/getenv "CHIRP_JOBS" "4")))

(defn- load-data [path] (parse (slurp (string repo "/" path))))
(def pins (load-data "pins.jdn"))
(def config (load-data "tools/build/config.jdn"))
(def natives (load-data "tools/build/natives.jdn"))

(defn- mkdirs [path]
  (var acc "")
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

# Commit time of the janet pin stands in for every embedded date.
(os/setenv "SOURCE_DATE_EPOCH" (capture "git" "-C" "src/janet" "log" "-1" "--format=%ct"))

(def prefix-map (string "-ffile-prefix-map=" abs-out "=."))

# OpenSSL, cached by pin. Installed under DESTDIR so build paths stay out of it.
(def ossl (config :openssl))
(def ossl-stage (string abs-out "/cache/openssl-" (string/slice (get-in pins [:openssl :commit]) 0 12)))
(def ossl-root (string ossl-stage (ossl :prefix)))
(unless (os/stat (string ossl-stage "/.done"))
  (in-dir "src/openssl"
    (run "./config" ;(ossl :configure) (string "--prefix=" (ossl :prefix)))
    (run "make" (string "-j" jobs) ;(ossl :make))
    (run "make" ;(ossl :install) (string "DESTDIR=" ossl-stage)))
  (spit (string ossl-stage "/.done") ""))
(def ossl-libs (map |(string ossl-root "/lib/" $) (ossl :libs)))

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

(def exe (config :exe))
(def exe-root (string abs-out "/obj/exe"))
(def exe-rules @{})
# The image reads data files the rules do not track, so always relink.
(os/execute ["rm" "-rf" exe-root] :px)
(with-dyns [cc/*rules* exe-rules
            cc/*build-type* :release
            cc/*janet-prefix* janet-prefix
            declare-cc/*build-root* exe-root]
  (sh/create-dirs (string exe-root "/release"))
  (def target
    (declare-cc/declare-executable
      :name (exe :name)
      :entry (string repo "/" (exe :entry))
      :static true
      :use-rdynamic false
      :use-rpath false
      :cflags [prefix-map]
      :lflags (exe :lflags)
      :static-libs @[;ossl-libs]))
  (build-rules/build-run exe-rules "build")
  (mkdirs "bin")
  (sh/copy target (string "bin/" (exe :name))))
