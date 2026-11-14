# HTTPS client and server

The bundled spork-https gives an HTTPS client and server on top of jsec's TLS streams. chirp adds a small overlay to the client; the server is upstream's.

## Client requests

```janet
(import spork-https :as https)

(def res (https/get "https://example.com/"))
(print (res :status))
(print (string/slice (res :body) 0 15))
```

The response is a table with `:status`, `:headers` and `:body`. `https/post`, `put`, `patch`, `delete`, `head`, `request` (method first) and `download` exist as well. Options go after the url: `:body`, `:headers`, `:max-redirects`, `:tls-opts`, `:stream-opts`.

## Default User-Agent

Some services, GitHub's API among them, reject requests without a `User-Agent`. chirp sends `User-Agent: chirp/<version>` when the request has none. A `User-Agent` you set, in any letter case, is sent unchanged:

```janet
(https/get "https://api.github.com/repos/roobie/chirp"
           :headers {"User-Agent" "my-tool"})
```

## Trusting only your own CA

`:tls-opts {:ca "ca.pem"}` makes that CA the only one the request trusts: a server whose certificate it did not sign is refused, even one your OS trusts. `:ca` takes a path or the PEM itself, in `:tls-opts` or `:stream-opts`:

```janet
(https/get "https://internal.example/" :tls-opts {:ca "internal-ca.pem"})
```

`:security {:ca-file ...}` adds a CA to the system store instead of replacing it.

## Trusting one certificate

`:trusted-cert` takes the certificate as PEM data, not a path. It suits a self-signed server:

```janet
(https/get "https://localhost:8443/" :tls-opts {:trusted-cert (slurp "server.pem")})
```

## Minimal HTTPS server

```janet
(import spork-https :as https)
(import jsec/cert)

(defn main [&]
  (def certs (cert/generate-self-signed-cert
               {:common-name "localhost" :organization "demo"
                :country "US" :days-valid 1 :bits 2048}))
  (def server
    (https/server (fn [req]
                    {:status 200
                     :headers {"Content-Type" "text/plain"}
                     :body (string "hello " (req :path))})
                  (certs :cert) (certs :key) "localhost" "8443"))
  (print "listening on https://localhost:8443/")
  # The server runs on the event loop; keep main alive.
  (forever (ev/sleep 3600)))
```

The handler receives the request table and returns a response table. The port is a string. `cert` and `key` are PEM strings or file paths. `(:close server)` stops it.
