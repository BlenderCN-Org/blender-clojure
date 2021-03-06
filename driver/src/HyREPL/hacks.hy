(import re)
(require [hy.contrib.walk [let]])
(import [HyREPL.utils [prepare-version-and-env-info]])

(setv re-cursive-file-wrapper (re.compile "^\\^{:clojure\\.core/eval-file.*?}"))

; here we emulate interactions with various nREPL clients:
; - lein repl :connect
; - Cursive's remote nREPL client

(defn reply-cursive-1 [session msg]
  [{"id"      (.get msg "id")
    "session" (.get msg "session")
    "value"   "#'cursive.repl.runtime/print-last-error"}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "status"  ["done"]}])

(defn reply-cursive-2 [session msg]
  [{"id"      (.get msg "id")
    "session" (.get msg "session")
    "ns"      "user"
    "value"   "nil"}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "status"  ["done"]}])

(defn reply-cursive-3 [session msg]
  [{"id"      (.get msg "id")
    "session" (.get msg "session")
    "out"     (.format "{}\n\n" (prepare-version-and-env-info))}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "status"  ["done"]}])

(defn reply-cursive-4 [session msg]
  [{"id"      (.get msg "id")
    "session" (.get msg "session")
    "ns"      "user"
    "value"   "{}"}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "status"  ["done"]}])

; Cursive: when using Send '...' to REPL, Cursive adds meta data about originating file
; e.g.
; {'code': '^{:clojure.core/eval-file "/Users/darwin/lab/blender-clojure/examples/aliases.hy" :line 5 :column 1} (clear)',
;  'id': 'c2c82812-6f81-494e-83ff-f05f50e24a8e',
;  'op': 'eval',
;  'session': '765296a2-a453-404e-a625-becf0adde045'}
;
; here we detect that situation and remove the metadata
;
; TODO: make Hy aware of this information somehow to improve backtraces
(defn transform-cursive-file-wrapper [session msg]
  (let [code (get msg "code")
        massaged-code (re.sub re-cursive-file-wrapper "" code)]
    (assoc msg "code" massaged-code)
    msg))

(defn reply-lein-intro [session msg]
  [{"id"      (.get msg "id")
    "session" (.get msg "session")
    "out"     (.format "{}\n\n" (prepare-version-and-env-info))}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "ns"      "Hy"
    "value"   "nil"}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "status"  ["done"]}])

(defn reply-lein-eval-modes [session msg]
  [{"id"      (.get msg "id")
    "session" (.get msg "session")
    "ns"      "Hy"
    "value"   "nil"}
   {"id"      (.get msg "id")
    "session" (.get msg "session")
    "status"  ["done"]}])

(defn hack [session msg]
  (let [op (.get msg "op")
        file (.get msg "file")
        code (.get msg "code")]
    (cond
      [(and (= op "load-file") (.startswith file "(ns cursive.repl.runtime"))
       (reply-cursive-1 session msg)]
      [(and (= op "eval") (= code "(get *compiler-options* :disable-locals-clearing)"))
       (reply-cursive-2 session msg)]
      [(and (= op "eval") (.startswith code "(do (clojure.core/println (clojure.core/str \"Clojure \" (clojure.core/clojure-version)))"))
       (reply-cursive-3 session msg)]
      [(and (= op "eval") (.startswith code "(cursive.repl.runtime/completions"))
       (reply-cursive-4 session msg)]
      [(and (= op "eval") (.startswith code "^{:clojure.core/eval-file"))
       (transform-cursive-file-wrapper session msg)]
      [(and (= op "eval") (.startswith code "(do (do (do (clojure.core/println (clojure.core/str \"REPL-y \""))
       (reply-lein-intro session msg)]
      [(and (= op "eval") (.startswith code "(clojure.core/binding [clojure.core/*ns* (clojure.core/or (clojure.core/find-ns (clojure.core/symbol \"reply.eval-modes.nrepl\"))"))
       (reply-lein-eval-modes session msg)])))
