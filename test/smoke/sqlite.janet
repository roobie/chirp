# sqlite3 is linked into the binary: a database file round-trips rows.
(import sqlite3)

(defn main [&]
  (def dir (or (os/getenv "TMPDIR") (os/getenv "TEMP") (os/getenv "TMP") "."))
  (def path (string dir "/chirp-smoke-" (os/time) "-" (math/floor (* 1e6 (math/random))) ".sqlite3"))
  (def db (sqlite3/open path))
  (var version nil)
  (defer (do (sqlite3/close db) (os/rm path))
    (sqlite3/eval db "CREATE TABLE birds (id INTEGER PRIMARY KEY, name TEXT, wingspan REAL);")
    (sqlite3/eval db "INSERT INTO birds (name, wingspan) VALUES (?, ?);" ["wren" 0.16])
    (sqlite3/eval db "INSERT INTO birds (name, wingspan) VALUES (:name, :span);"
                  {:name "swan" :span 2.2})
    (def rows (sqlite3/eval db "SELECT id, name, wingspan FROM birds ORDER BY id;"))
    (assert (= 2 (length rows)) "two rows come back")
    (assert (= "wren" ((rows 0) :name)) "first name")
    (assert (= 0.16 ((rows 0) :wingspan)) "first wingspan")
    (assert (= "swan" ((rows 1) :name)) "second name")
    (assert (= 2 (sqlite3/last-insert-rowid db)) "rowid of the last insert")
    (set version (get-in (sqlite3/eval db "SELECT sqlite_version() AS v;") [0 :v])))
  (assert (not (os/stat path)) "database file is deleted")
  (print "ok sqlite3 " version))
