(import
  sys
  threading
  time
  bclj.hy
  [socketserver [ThreadingMixIn TCPServer BaseRequestHandler]])

(import [HyREPL [bencode session]])
(import [HyREPL.middleware [base eval]])

(require [hy.contrib.walk [let]])

(defclass ReplServer [ThreadingMixIn TCPServer]
  (setv allow-reuse-address True)
  (setv daemon_threads True))

(defclass ReplRequestHandler [BaseRequestHandler]
  (setv session None)
  (defn handle [self]
    (bclj.hy.repl_logger.info (.format "New HyREPL client {}" self.request))
    (let [buf (bytearray)
          transport self.request
          tmp None
          msg None]
      (while True
        ; receive data
        (try
          (setv tmp (.recv transport 1024))
          (except [e OSError]
            (break)))
        (when (zero? (len tmp))
          (break))
        (.extend buf tmp)
        ; decode buffer
        (try
          (let [decoded (bencode.decode buf)
                _ (setv msg (get decoded 0))
                rest (get decoded 1)]
            (.clear buf)
            (.extend buf rest))
          (except [e Exception]
            ;(bclj.hy.repl_logger.exception "Unable to decode REPL message" :stack_info True)
            (continue)))
        ; setup session
        (if-not self.session
          (setv self.session (or (.get session.sessions (.get msg "session"))
                                 (session.Session))))
        ; request session job
        (bclj.hy.handle_session_message self.session msg transport)))
    (bclj.hy.repl_logger.info (.format "HyREPL Client gone {}" self.request))))


(defn start-server [&optional [host "127.0.0.1"] [port 1337]]
  (let [s (ReplServer (, host port) ReplRequestHandler)
        t (threading.Thread :target s.serve-forever)]
    (setv t.daemon True)
    (.start t)
    (, t s)))

(defn shutdown-server [server]
  (let [t (first server)
        s (second server)]
    (.shutdown s)
    (.server_close s)))

(defn read-port-from-args [args]
  (if (> (len args) 0)
    (try
      (int (last args))
      (except [_ ValueError]))))

(defmain [&rest args]
  (setv port (or (read-port-from-args args) 1337))
  (while True
    (try
      (start-server "127.0.0.1" port)
      (except [e OSError]
        (setv port (inc port)))
      (else
        (bclj.hy.repl_logger.info (.format "HyREPL listening on {}" port))
        (while True
          (time.sleep 1))))))
