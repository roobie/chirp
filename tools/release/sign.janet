# Sign or verify a release's SHA256SUMS with Ed25519, using chirp's own jsec so
# the release is signed by the code it ships. The private key comes only from
# the environment, so it is never an argument or a file in the workspace.
#   chirp sign.janet sign   <sums> <sig-out> [--key-env NAME]
#       (the key is in the variable NAME, CHIRP_RELEASE_SIGNING_KEY by default)
#   chirp sign.janet verify <sums> <sig> <public-key.pem>
(import jsec/crypto)

(def default-key-env "CHIRP_RELEASE_SIGNING_KEY")

(defn sign
  "Writes the signature of the file `sums` to `sig`, with the private key in the
  environment variable `key-env`."
  [sums sig &opt key-env]
  (default key-env default-key-env)
  (def key (os/getenv key-env))
  (unless (and key (not (empty? key))) (error (string key-env " is not set")))
  (spit sig (crypto/sign key (slurp sums))))

(defn verify
  "Errors unless `sig` is a signature of the file `sums` by the public key in `pub`."
  [sums sig pub]
  (unless (crypto/verify (slurp pub) (slurp sums) (slurp sig))
    (error (string sig " does not verify against " pub))))

(def- usage
  (string "usage: sign.janet sign <sums> <sig-out> [--key-env NAME] | verify <sums> <sig> <public-key.pem>"))

(defn main [_ & args]
  (def [mode sums sig third fourth] args)
  (case [mode (length args)]
    ["sign" 3] (sign sums sig)
    ["sign" 5] (if (= third "--key-env") (sign sums sig fourth) (error usage))
    ["verify" 4] (verify sums sig third)
    (error usage)))
