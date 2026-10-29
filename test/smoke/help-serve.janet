# `chirp --help serve` answers pages from the baked-in help on a local port.
(import spork/http)

(defn- strip-cr [s] (string/replace-all "\r" "" s))

(defn- start
  "Spawn the server on a random port; returns [proc port], or nil if the port
  was taken."
  []
  (def port (+ 20000 (math/rng-int (math/rng (+ (os/time) (math/floor (* 1e6 (math/random))))) 30000)))
  (def p (os/spawn [(dyn *executable*) "--help" "serve" "--host" "127.0.0.1" "--port" (string port)] :p
                   {:out :pipe :err :pipe}))
  (def line
    (try
      (ev/with-deadline 20 (strip-cr (string (ev/read (p :out) 1024))))
      ([_] "")))
  (if (string/find "serving chirp help at http://127.0.0.1:" line)
    (do (assert (string/find (string ":" port "/ (Ctrl-C stops)") line) (string "start line: " line))
        [p port])
    (do (os/proc-kill p true) nil)))

(defn- serve-fails [& args]
  (def b (os/spawn [(dyn *executable*) "--help" "serve" ;args] :p {:out :pipe :err :pipe}))
  (def [_ berr] (ev/gather (ev/read (b :out) :all) (ev/read (b :err) :all)))
  [(os/proc-wait b) (string berr)])

(defn main [&]
  (var started nil)
  (for attempt 0 5
    (unless started (set started (start))))
  (assert started "server did not start")
  (def [p port] started)
  (defer (os/proc-kill p true)
    (defn get* [path]
      (def r (http/request "GET" (string "http://127.0.0.1:" port path)))
      [(r :status) (strip-cr (string (r :body))) (r :headers)])

    (def [hs hb] (get* "/"))
    (assert (and (= 200 hs) (string/find "sqlite" hb) (string/find "href=\"/read/sqlite\"" hb)) "home lists topics")

    (def [ss sb] (get* "/search?q=sqlite"))
    (assert (and (= 200 ss) (string/find "href=\"/read/" sb) (string/find "<html" sb)) "search page has results")

    (def [fs fb] (get* "/search?fragment=1&q=sqlite"))
    (assert (and (= 200 fs) (string/find "href=\"/read/" fb) (not (string/find "<html" fb))) "fragment is bare results")

    (def [rs rb] (get* "/read/chirp"))
    (assert (and (= 200 rs) (string/find "<h1>chirp</h1>" rb) (string/find "href=\"/read/chirp/usage\"" rb))
            "topic renders its heading and links its sections")

    (def [cs cb] (get* "/read/chirp/usage"))
    (assert (and (= 200 cs) (string/find "href=\"/read/chirp\"" cb)) "section links its topic")

    (def [ds db] (get* "/read/spork-https/get"))
    (assert (and (= 200 ds) (string/find "chirp adds" db) (string/find "<pre>" db)) "docstring page")

    (def [os_ ob] (get* "/read/os/spawn"))
    (assert (= 200 os_) "core docstring page")
    (def [ps _] (get* "/read/%3E"))
    (assert (= 200 ps) "percent-encoded core name decodes")

    (def [bs bb] (get* "/search?q=%22"))
    (assert (and (= 400 bs) (string/find "Invalid query" bb)) "invalid query is 400")

    (def [xs xb] (get* "/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E"))
    (assert (not (string/find "<script>alert" xb)) "query is escaped")
    (assert (string/find "&lt;script&gt;alert" xb) "escaped query is echoed")

    (def [ys yb yh] (get* "/style.css"))
    (assert (and (= 200 ys) (string/has-prefix? "text/css" (yh "content-type")) (string/find "--bg" yb))
            "stylesheet")

    (assert (= 404 ((get* "/nope") 0)) "unknown path is 404")
    (assert (= 404 ((get* "/read/no-such-id") 0)) "unknown id is 404")
    # The server survives all of the above.
    (assert (= 200 ((get* "/") 0)) "still serving")

    # A taken port is a one-line error, exit 1.
    (def [tcode terr] (serve-fails "--host" "127.0.0.1" "--port" (string port)))
    (assert (and (= 1 tcode) (string/find "cannot listen" terr) (not (string/find "error:" terr)))
            (string "taken port: " tcode " " terr)))

  # Bad options are usage errors, not a server.
  (def [bcode berr] (serve-fails "--bogus"))
  (assert (= 2 bcode) "--bogus exits 2")
  (assert (string/find "--bogus" berr) "--bogus is named on stderr")
  (assert (= 2 ((serve-fails "--host") 0)) "--host without a value exits 2")
  (assert (= 2 ((serve-fails "--port" "x") 0)) "bad --port exits 2")
  (print "ok help-serve on port " port))
