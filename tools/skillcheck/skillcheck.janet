# Keeps the repo's skills in the layout the installer gives other projects
# (D-HLIOIUOA4NCCKNJI): each skill is a real directory under the canonical dir,
# and each agent dir holds only relative links to those directories. Both dirs
# come from src/chirp/chirp.jdn. It reads the git index, so it checks exactly
# what a commit would hold, whatever the working tree has.
#   skillcheck.janet        check the index

(def- link-mode "120000")

(defn- run
  "Run a command; return [exit-code stdout]."
  [& args]
  (def p (os/spawn args :p {:out :pipe}))
  (def out (or (ev/read (p :out) :all) @""))
  [(os/proc-wait p) (string out)])

(defn- git [& args]
  (def [code out] (run "git" ;args))
  (unless (zero? code) (error (string "git " (string/join args " ") " failed")))
  out)

(defn- under
  "The path below dir/, or nil when path is not inside dir."
  [dir path]
  (def p (string dir "/"))
  (when (string/has-prefix? p path) (string/slice path (length p))))

(defn link-target
  "The relative target a link in agent dir `link-dir` must have for skill `name`."
  [link-dir canonical name]
  (def depth (length (string/split "/" link-dir)))
  (string (string/repeat "../" depth) canonical "/" name))

(defn problems
  "Layout problems, as strings. entries are [mode path] from the index;
  target-of maps a link's path to its target."
  [entries canonical links target-of]
  (def found @[])
  (def skills @{})
  (def has-skill-md @{})
  (each [mode path] entries
    (when-let [rest (under canonical path)]
      (def parts (string/split "/" rest))
      (if (= 1 (length parts))
        (array/push found (string path ": a file directly in " canonical "; skills are directories"))
        (do
          (put skills (first parts) true)
          (when (and (= 2 (length parts)) (= "SKILL.md" (parts 1)))
            (put has-skill-md (first parts) true))
          (when (= mode link-mode)
            (array/push found (string path ": a link inside " canonical "; skills there are real files")))))))
  (eachk name skills
    (unless (has-skill-md name)
      (array/push found (string canonical "/" name ": has no SKILL.md"))))
  (each l links
    (def present @{}) # anything under l/<name>; a wrong entry is reported once, as wrong
    (each [mode path] entries
      (when-let [rest (under l path)]
        (def name (first (string/split "/" rest)))
        (put present name true)
        (def want (link-target l canonical name))
        (cond
          (not= rest name)
          (array/push found (string path ": a real file in " l "; put the skill in "
                                    canonical "/" name " and link " l "/" name " -> " want))
          (not= mode link-mode)
          (array/push found (string path ": not a link; make it a link -> " want))
          (not= (target-of path) want)
          (array/push found (string path ": links to " (target-of path) ", want " want))
          (not (skills name))
          (array/push found (string path ": links to " want ", which is not a skill in the index")))))
    (eachk name skills
      (unless (present name)
        (array/push found (string canonical "/" name ": no link " l "/" name
                                  " -> " (link-target l canonical name))))))
  (sort found))

(defn main [_ &opt mode]
  (when mode
    (eprint "usage: skillcheck.janet")
    (os/exit 2))
  (def top (string/trim (git "rev-parse" "--show-toplevel")))
  (def cfg (parse (slurp (string top "/src/chirp/chirp.jdn"))))
  (def canonical (cfg :skill-canonical))
  (def links (cfg :skill-links))
  (def entries @[])
  (def shas @{})
  (each line (string/split "\0" (git "-C" top "ls-files" "-s" "-z" "--" canonical ;links))
    (unless (empty? line)
      (def [meta path] (string/split "\t" line 0 2))
      (def [mode sha] (string/split " " meta))
      (array/push entries [mode path])
      (put shas path sha)))
  (defn target-of [path] (git "-C" top "cat-file" "blob" (shas path)))
  (def found (problems entries canonical links target-of))
  (each f found (eprint "skillcheck: " f))
  (when (pos? (length found))
    (eprintf "skillcheck: %d problem(s). Each skill lives in %s/<name>; %s hold links to it (D-HLIOIUOA4NCCKNJI)."
             (length found) canonical (string/join links ", "))
    (os/exit 1)))
