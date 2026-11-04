# On windows, tls/connect must wait for the TCP connect before the handshake
# starts (#10). jsec used to start the handshake as soon as a non-blocking
# connect was under way, so with any real network latency the first send failed
# with WSAENOTCONN ("Write syscall error: WSA error 10057"). A loopback connect
# finishes too fast to show it, so the listener here sets SO_CONDITIONAL_ACCEPT:
# windows then holds the TCP handshake until the server accepts, which this
# check does only after a pause. Wine has no conditional accept, so under Wine
# the check is skipped.
(import jsec/tls)

(def- AF_INET 2)
(def- SOCK_STREAM 1)
(def- IPPROTO_TCP 6)
(def- SOL_SOCKET 0xffff)
(def- SO_CONDITIONAL_ACCEPT 0x3002)
(def- FIONBIO 0x8004667e)

(defn- int32-le [n] (buffer/push-uint32 @"" :le n))

(defn main [&]
  (unless (index-of (os/which) [:windows :mingw])
    (print "skip tls-connect-wait: the race is windows only")
    (os/exit 0))

  # SOCKET is pointer sized, so it travels as :ptr.
  (def ws2 (ffi/native "ws2_32.dll"))
  (defn bind-fn [name ret & args]
    (def f (ffi/lookup ws2 name))
    (def sig (ffi/signature :default ret ;args))
    (fn [& xs] (ffi/call f sig ;xs)))
  (def socket (bind-fn "socket" :ptr :int32 :int32 :int32))
  (def setsockopt (bind-fn "setsockopt" :int32 :ptr :int32 :int32 :ptr :int32))
  (def bind (bind-fn "bind" :int32 :ptr :ptr :int32))
  (def getsockname (bind-fn "getsockname" :int32 :ptr :ptr :ptr))
  (def listen (bind-fn "listen" :int32 :ptr :int32))
  (def wsa-accept (bind-fn "WSAAccept" :ptr :ptr :ptr :ptr :ptr :ptr))
  (def ioctlsocket (bind-fn "ioctlsocket" :int32 :ptr :uint32 :ptr))
  (def recv (bind-fn "recv" :int32 :ptr :ptr :int32 :int32))
  (def closesocket (bind-fn "closesocket" :int32 :ptr))

  (def lsock (socket AF_INET SOCK_STREAM IPPROTO_TCP))
  (unless (zero? (setsockopt lsock SOL_SOCKET SO_CONDITIONAL_ACCEPT (int32-le 1) 4))
    (closesocket lsock)
    (print "skip tls-connect-wait: no SO_CONDITIONAL_ACCEPT here (Wine?)")
    (os/exit 0))
  # sockaddr_in for 127.0.0.1, port 0 (any free port).
  (def addr (buffer/from-bytes AF_INET 0 0 0 127 0 0 1 0 0 0 0 0 0 0 0))
  (assert (zero? (bind lsock addr 16)) "bind failed")
  (def addrlen (int32-le 16))
  (assert (zero? (getsockname lsock addr addrlen)) "getsockname failed")
  (def port (bor (blshift (get addr 2) 8) (get addr 3)))
  (assert (zero? (listen lsock 4)) "listen failed")

  # The client's write starts the handshake. No server ever answers it, so on a
  # fixed build the write waits; the broken build fails it at once.
  (def client-error @[])
  (def client
    (ev/go (fn []
             (try
               (let [c (tls/connect "127.0.0.1" (string port) {:verify false})]
                 (ev/write c "hello"))
               ([err] (array/push client-error err))))))

  (ev/sleep 0.5)
  (assert (empty? client-error)
          (string/format "tls/connect did not wait for the TCP connect: %s"
                         (first client-error)))

  # Now let the TCP handshake finish; the ClientHello should follow it.
  (def conn (wsa-accept lsock nil nil nil nil))
  (ioctlsocket conn FIONBIO (int32-le 1))
  (def buf (buffer/new-filled 16 0))
  (var got -1)
  (for _ 0 100
    (ev/sleep 0.05)
    (set got (recv conn buf 16 0))
    (when (pos? got) (break)))
  (closesocket conn)
  (closesocket lsock)
  (ev/cancel client "done")
  (assert (empty? client-error)
          (string/format "client failed: %s" (first client-error)))
  (assert (pos? got) "no ClientHello arrived after the connect was accepted")
  # A TLS record of type handshake (22) opens the ClientHello.
  (assert (= 0x16 (get buf 0)) (string/format "first byte %d, not a TLS handshake" (get buf 0)))
  (print "ok tls-connect-wait: the handshake started after the TCP connect"))
