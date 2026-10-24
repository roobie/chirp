# Sign or verify a release's SHA256SUMS with Ed25519, using chirp's own jsec so
# the release is signed by the code it ships. The private key comes only from
# the environment, so it is never an argument or a file in the workspace.
#   chirp sign.janet sign   <sums> <sig-out>      (key in CHIRP_RELEASE_SIGNING_KEY)
#   chirp sign.janet verify <sums> <sig> <public-key.pem>
(import jsec/crypto)

(defn main [_ mode sums sig & rest]
  (def data (slurp sums))
  (case mode
    "sign"
    (do
      (def key (os/getenv "CHIRP_RELEASE_SIGNING_KEY"))
      (unless (and key (not (empty? key))) (error "CHIRP_RELEASE_SIGNING_KEY is not set"))
      (spit sig (crypto/sign key data)))

    "verify"
    (do
      (def [pub] rest)
      (unless pub (error "verify needs the public key file"))
      (unless (crypto/verify (slurp pub) data (slurp sig))
        (error (string sig " does not verify against " pub))))

    (error (string "unknown mode " mode))))
