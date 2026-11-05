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
  "Write the OS store's roots to the export file. Returns [path nil], or
  [nil why] when it cannot, why being nil where the OS has no store."
  []
  (def [ok res] (protect (osroots/export)))
  (def path (export-path))
  (cond
    (not ok) [nil res]
    (nil? res) [nil nil]
    (nil? path) [nil (string (store-name) ": no cache directory to export to")]
    (or (holds? path (res 0)) (write-file path (res 0))) [path nil]
    [nil (string (store-name) ": cannot write " path)]))

(defn setup
  "Point SSL_CERT_FILE at a trust file that needs no export, and return how to
  describe it, or nil when only the OS's store is left (see from-store).
  SSL_CERT_FILE, when set, wins. Otherwise the first file of paths that exists
  is used, paths being keyed by (os/which) with :default for the rest."
  [paths]
  (def env (os/getenv "SSL_CERT_FILE"))
  (cond
    # A chirp started by chirp inherits the export its parent wrote.
    (and env (= env (export-path))) (string (store-name) " (" env ")")
    env env
    (when-let [p (find os/stat (get paths (os/which) (paths :default)))]
      (os/setenv "SSL_CERT_FILE" p)
      p)))

(var- stored nil)

(defn from-store
  "Export the OS store's roots, point SSL_CERT_FILE at them and return how to
  describe that: nil where the OS has no store, or a description starting
  \"none found\" that says why the store could not be used. Reading the
  macOS keychain takes a few hundred milliseconds, so this runs once, when
  something first needs TLS."
  []
  (unless stored
    (def [f why] (export))
    (set stored
         (cond
           f (do (os/setenv "SSL_CERT_FILE" f) (string (store-name) " (" f ")"))
           why (string "none found (" why ")")
           :none)))
  (unless (= stored :none) stored))
