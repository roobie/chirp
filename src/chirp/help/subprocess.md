# Subprocesses

`os/execute` runs a program and waits for its exit code; `os/spawn` starts it and returns a process to read from and wait on. Both take the program and its arguments as one array, then flags, then an optional table of options.

## Run in another directory

Put `:cd` in the options table to start the child in that directory. The parent's own directory does not change, so relative paths elsewhere in the script and other fibers are unaffected; `os/cd` would move the whole process. chirp 0.7.0 makes this work on linux; Janet's docstrings do not mention `:cd`.

```janet
(os/execute ["git" "status" "--short"] :p {:cd "../other-repo"})

(def p (os/spawn ["ls"] :p {:cd "/tmp" :out :pipe}))
(print (ev/read (p :out) :all))
(os/proc-wait p)
```

A missing directory raises an error rather than running the child where the script is; on linux the error's message can name an unrelated cause, such as `Not a tty`, because Janet reports a stale `errno`. A relative program path, such as `./tool`, is looked up from the new directory, so pass an absolute one (`os/realpath`).

## Set environment variables

The `:e` flag makes the options table the child's whole environment: everything not in it, `PATH` and `HOME` included, is gone. To change one variable, merge it over the current environment:

```janet
(os/execute ["make"] :pe (merge (os/environ) {"CC" "zig cc" :cd "build"}))
```

`:cd`, `:in`, `:out` and `:err` work with or without `:e`.

## spork/sh

`spork/sh` (`sh/exec`, `sh/exec-slurp` and the rest) takes only the command, so for a working directory or environment use `os/execute` or `os/spawn`.
