# `chirp --<skill> --install`. collect runs while the image is built and its
# result is baked in; install lays the files out the way the npm `skills`
# package does: one canonical copy, and each agent directory links to it.
(import spork/sh)

(defn- walk
  "Sorted paths of the files under dir, relative to it, with `/` separators."
  [dir &opt prefix]
  (default prefix "")
  (def out @[])
  (each name (os/dir dir)
    (def rel (string prefix name))
    (if (= :directory (os/stat (string dir "/" name) :mode))
      (array/concat out (walk (string dir "/" name) (string rel "/")))
      (array/push out rel)))
  (sorted out))

(defn collect
  "Sorted [relative-path content] pairs of the files under dir, minus those
  whose name ends in one of the exclude suffixes."
  [dir exclude]
  (def files
    (seq [rel :in (walk dir)
          :unless (some |(string/has-suffix? $ rel) exclude)]
      [rel (string (slurp (string dir "/" rel)))]))
  (assert (not (empty? files)) (string "no skill files in " dir))
  files)

# Paths ---------------------------------------------------------------------

(defn- real [path] (let [[ok p] (protect (os/realpath path))] (when ok p)))

(defn- parts [path] (filter |(not (empty? $)) (string/split "/" (string/replace-all "\\" "/" path))))

(defn- relative
  "Path from the directory `from` to `to`, both absolute and without symlinks."
  [from to]
  (def [a b] [(parts from) (parts to)])
  (var n 0)
  (while (and (< n (length a)) (< n (length b)) (= (a n) (b n))) (++ n))
  # Another Windows drive has no relative path.
  (if (and (zero? n) (string/has-suffix? ":" (get a 0 "")))
    to
    (string/join [;(map (fn [_] "..") (slice a n)) ;(slice b n)] "/")))

(defn- home []
  (or (os/getenv "HOME") (os/getenv "USERPROFILE")))

# Copies ----------------------------------------------------------------------

(defn- differences
  "Relative paths under dest that differ from files: changed, missing, extra."
  [dest files]
  (def shipped @{})
  (def out @[])
  (each [rel content] files
    (put shipped rel true)
    (def [ok have] (protect (slurp (string dest "/" rel))))
    (cond
      (not ok) (array/push out (string rel " (missing)"))
      (not= (string have) content) (array/push out (string rel " (changed)"))))
  (each rel (walk dest)
    (unless (shipped rel) (array/push out (string rel " (extra)"))))
  (sorted out))

(defn- dirname [path] (string/slice path 0 (last (string/find-all "/" path))))

(defn- write-files [dest files]
  (each [rel content] files
    (def path (string dest "/" rel))
    (sh/create-dirs (dirname path))
    (spit path content)))

# Nothing under a directory the user may have edited is overwritten or deleted
# unless --force names it, and --force still writes only the shipped files.
(defn- put-copy
  "Make dest (shown as shown) hold files. Returns false when it was refused."
  [dest shown files force]
  (case (os/stat dest :mode)
    nil (do (write-files dest files)
          (print"wrote " shown " (" (length files) " files)")
          true)
    :directory
    (let [diff (differences dest files)
          extra (filter |(string/has-suffix? " (extra)" $) diff)]
      (cond
        (empty? diff) (do (print"up to date " shown) true)
        force (do (write-files dest files)
                (print"rewrote " shown " (" (length files) " files)")
                (unless (empty? extra)
                  (print"left in place: " (string/join extra ", ")))
                true)
        (do (eprint "refused: " shown " differs from the shipped files; --force rewrites them")
          (each d diff (eprint "  " d))
          false)))
    (do (eprint "skipped: " shown " exists and is not a directory")
      false)))

# Links -------------------------------------------------------------------------

(defn- skip [shown path mode]
  (eprint "skipped: " shown " is "
          (if (= :link mode)
            (string "a link to " (os/readlink path))
            (string "a " (if (= :directory mode) "directory" "file")))
          " that is not this skill's link; left alone")
  false)

(defn- link-or-copy
  "Link base/shown to the canonical dir. Returns false when skipped or refused."
  [base shown canon-real files force]
  (def path (string base "/" shown))
  (def mode (os/lstat path :mode))
  (cond
    # Also the case when the agent dir is itself a link to the canonical parent.
    (and mode (= canon-real (real path)))
    (do (print"up to date " shown) true)

    mode (skip shown path mode)

    (do
      (def parent (dirname path))
      (sh/create-dirs parent)
      (def target (relative (or (real parent) parent) canon-real))
      (def [ok err] (protect (os/symlink target path)))
      (cond
        ok (do (print"linked " shown " -> " target) true)
        # Windows without the privilege to make links, among others. Upstream
        # uses a junction there; Janet has no way to make one.
        (do (print"cannot link " shown " (" err "); copying instead")
          (put-copy path shown files force))))))

(defn- install-skill [opts name files conf]
  (def base (opts :base))
  (def canon (string (conf :canonical) "/" name))
  (var ok true)
  (defn note [good] (unless good (set ok false)))
  (if (opts :copy)
    (each dir (conf :links)
      (def shown (string dir "/" name))
      (def path (string base "/" shown))
      (note (if (= :link (os/lstat path :mode))
              (skip shown path :link)
              (put-copy path shown files (opts :force)))))
    (if (put-copy (string base "/" canon) canon files (opts :force))
      (let [canon-real (real (string base "/" canon))]
        (each dir (conf :links)
          (note (link-or-copy base (string dir "/" name) canon-real files (opts :force)))))
      (set ok false)))
  ok)

# Command -------------------------------------------------------------------------

(defn- usage [name]
  (string "Usage: chirp --" name " --install [-g|--global] [--copy] [--force]\n"
          "  --install     put the " name " skill in the current directory\n"
          "  -g, --global  put it in the home directory instead\n"
          "  --copy        write real copies into the agent directories, no links\n"
          "  --force       rewrite shipped files that differ from the installed ones\n"))

(defn- parse-args [name args]
  (def opts @{})
  (each a args
    (case a
      "--install" (put opts :install true)
      "-g" (put opts :global true)
      "--global" (put opts :global true)
      "--copy" (put opts :copy true)
      "--force" (put opts :force true)
      "-h" (put opts :help true)
      "--help" (put opts :help true)
      (do (eprint "chirp --" name ": unknown argument " a)
        (eprint (usage name))
        (os/exit 2))))
  opts)

(defn run
  "Run `chirp --<name>`. args are the words after it; conf has :skills (name
  to collected files), :canonical and :links. Exits 1 if anything was skipped
  or refused, 2 on a usage error."
  [name args conf]
  (def opts (parse-args name args))
  (when (or (empty? args) (opts :help))
    (prin (usage name))
    (os/exit 0))
  (unless (opts :install)
    (eprint "chirp --" name ": nothing to do without --install")
    (eprint (usage name))
    (os/exit 2))
  (def base (if (opts :global)
              (or (home) (do (eprint "chirp --" name ": no HOME to install into") (os/exit 2)))
              (os/cwd)))
  (put opts :base base)
  (print"installing " name " into " base)
  (unless (install-skill opts name ((conf :skills) name) conf)
    (os/exit 1)))
