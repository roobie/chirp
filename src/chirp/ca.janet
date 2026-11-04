# Where chirp's TLS trust comes from: always the OS, never chirp itself. jsec
# loads OpenSSL's default trust, which OpenSSL reads from the file named by
# SSL_CERT_FILE. Linux and the BSDs keep such a file. macOS and windows keep
# their trust in stores of their own, so chirp exports the roots those trust to
# a file in the user's cache directory and names that.
(import osroots)

(defn- windows? [] (truthy? (index-of (os/which) [:windows :mingw])))

(defn- store-name [] (if (windows?) "windows store" "keychain"))

(defn- cache-root
  "The per-user cache directory of this OS, or nil without one."
  []
  (cond
    (windows?) (os/getenv "LOCALAPPDATA")
    (= :macos (os/which)) (when-let [h (os/getenv "HOME")] (string h "/Library/Caches"))
    (or (os/getenv "XDG_CACHE_HOME")
        (when-let [h (os/getenv "HOME")] (string h "/.cache")))))

(defn- export-path []
  (when-let [root (cache-root)] (string root "/chirp/os-roots.pem")))

(defn- holds? [path pem] (= pem (try (string (slurp path)) ([_] nil))))

(defn- write-file
  "Make path hold exactly pem, through a temporary file so a reader never sees
  half of it. Windows will not rename over a file, so a stale one goes first;
  another chirp may win the race, which is fine if the file ends up right."
  [path pem]
  (def dir (string/slice path 0 (last (string/find-all "/" path))))
  (each d [(string/slice dir 0 (last (string/find-all "/" dir))) dir]
    (try (os/mkdir d) ([_] nil)))
  (def tmp (string path "." (os/getpid) ".tmp"))
  (try
    (do
      (spit tmp pem)
      (when (and (windows?) (os/stat path)) (os/rm path))
      (os/rename tmp path))
    ([_] (try (os/rm tmp) ([_] nil))))
  (holds? path pem))

(defn- export
  "Write the OS store's roots to the export file and return it, or nil."
  []
  (when-let [path (export-path)
             [pem _] (osroots/export)]
    (when (or (holds? path pem) (write-file path pem))
      path)))

(defn setup
  "Point SSL_CERT_FILE at the trust store and return how to describe it, or nil
  when the OS offers none. SSL_CERT_FILE, when set, wins. Otherwise the first
  file of paths that exists is used, paths being keyed by (os/which) with
  :default for the rest, and then the OS's own store."
  [paths]
  (def env (os/getenv "SSL_CERT_FILE"))
  (defn choose [path description] (os/setenv "SSL_CERT_FILE" path) description)
  (cond
    # A chirp started by chirp inherits the export its parent just wrote.
    (and env (= env (export-path))) (string (store-name) " (" env ")")
    env env
    (or (when-let [p (find os/stat (get paths (os/which) (paths :default)))] (choose p p))
        (when-let [f (export)] (choose f (string (store-name) " (" f ")"))))))
