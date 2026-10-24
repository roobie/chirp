# Replacement client functions for the bundled spork-https; main.janet puts them
# over the upstream bindings, named by :overlays in chirp.jdn. Every entry point
# is wrapped because upstream get/post/... reach request through compiled
# references, so replacing one binding alone would change nothing.
(import spork-https :as up)

(def- here
  (let [f (dyn *current-file*)]
    (string/slice f 0 (+ 1 (last (string/find-all "/" f))))))
# One source for the version: the same file main.janet reads.
(def- user-agent (string "chirp/" ((parse (slurp (string here "chirp.jdn"))) :version)))

(defn- has-user-agent? [headers]
  (truthy? (find |(= "user-agent" (string/ascii-lower (string $))) (keys headers))))

(defn- fix-headers [headers]
  (def h (table ;(kvs (or headers {}))))
  (unless (has-user-agent? h) (put h "User-Agent" user-agent))
  h)

# jsec clients ignore :ca and read :security {:ca-file ...} instead.
(defn- fix-tls [tls]
  (if (and tls (tls :ca))
    (let [t (table ;(kvs tls))
          security (table ;(kvs (or (tls :security) {})))]
      (unless (security :ca-file) (put security :ca-file (tls :ca)))
      (put t :security security))
    tls))

(defn- fix-opts [opts]
  (def o (table ;(kvs opts)))
  (put o :headers (fix-headers (o :headers)))
  (each k [:tls-opts :stream-opts]
    (when (o k) (put o k (fix-tls (o k)))))
  (kvs o))

(defmacro- wrap [name params]
  (def doc (((require "spork-https") name) :doc))
  ~(defn ,name ,(string doc "\n\nchirp adds: a default User-Agent header, and :ca in :tls-opts and :stream-opts as :security {:ca-file}.")
     [,;params &keys opts]
     (,(symbol "up/" name) ,;params ;(fix-opts opts))))

(wrap request [method url])
(wrap open-stream [url])
(wrap download [url dest])
# These shadow core get/put/delete from here on, as upstream does.
(wrap get [url])
(wrap post [url])
(wrap put [url])
(wrap patch [url])
(wrap delete [url])
(wrap head [url])
