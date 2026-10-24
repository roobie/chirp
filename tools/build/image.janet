# Write chirp's image and main as C source.
# Usage: janet image.janet <outdir> <repo> <static-lib>...
# Run by build.janet as a fresh process: compiling the entry point calls gensym
# and the names end up in the image, so the image depends only on this file and
# the pinned spork, never on build.janet. Editing this file changes hashes.

(def [_ out repo & ossl-libs] (dyn *args*))
(os/cd out)
(def abs-out (os/cwd))

(def config (parse (slurp (string repo "/tools/build/config.jdn"))))

# Janet source and native modules, as seen by the image-building janet.
# Relative paths keep recorded source locations identical across out dirs.
(each name (config :janet-sources)
  (array/push module/paths [(string "src/" name "/:all:.janet") :source]))
(array/push module/paths ["modpath/:all:.so" :native])

(import spork/build-rules)
(import spork/cc)
(import spork/declare-cc)
(import spork/sh)

(def exe (config :exe))
(def exe-root (string abs-out "/obj/exe"))
(def rules @{})
# The image reads data files the rules do not track, so always regenerate.
(os/execute ["rm" "-rf" exe-root] :px)
(with-dyns [cc/*rules* rules
            cc/*build-type* :release
            cc/*janet-prefix* (string abs-out "/prefix")
            declare-cc/*build-root* exe-root]
  (sh/create-dirs (string exe-root "/release"))
  (declare-cc/declare-executable
    :name (exe :name)
    :entry (string repo "/" (exe :entry))
    :static true
    :use-rdynamic false
    :use-rpath false
    # Stop after writing the image and main as C source; zig links it.
    :no-compile true
    :cflags [(string "-ffile-prefix-map=" abs-out "=.")]
    :static-libs @[;ossl-libs])
  (build-rules/build-run rules "build"))
