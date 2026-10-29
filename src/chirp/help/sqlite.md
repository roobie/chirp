# SQLite

The `sqlite3` module embeds SQLite, so no system library is needed. It was added in chirp 0.2.0.

## Open a database

```janet
(import sqlite3)

(def db (sqlite3/open "notes.db"))   # or ":memory:"
# ... use db ...
(sqlite3/close db)
```

## Run statements with parameters

`sqlite3/eval` takes the database, the SQL and optionally parameters: an array for `?` placeholders, a struct or table for named ones.

```janet
(sqlite3/eval db "CREATE TABLE birds (id INTEGER PRIMARY KEY, name TEXT, wingspan REAL);")
(sqlite3/eval db "INSERT INTO birds (name, wingspan) VALUES (?, ?);" ["wren" 0.16])
(sqlite3/eval db "INSERT INTO birds (name, wingspan) VALUES (:name, :span);"
              {:name "swan" :span 2.2})
(print (sqlite3/last-insert-rowid db))
```

## Rows are structs

A query returns an array of structs keyed by column name as keywords. Structs are immutable; `(thaw row)` gives a mutable table copy.

```janet
(def rows (sqlite3/eval db "SELECT name, wingspan FROM birds ORDER BY id;"))
(print ((rows 0) :name) " " ((rows 1) :wingspan))
```

Integer columns come back as numbers; text as strings.

## Full-text search with FTS5

FTS5 is compiled in. Create a virtual table, insert, and query with `MATCH`; `bm25` ranks by relevance, lower is better:

```janet
(sqlite3/eval db "CREATE VIRTUAL TABLE docs USING fts5(title, body);")
(sqlite3/eval db "INSERT INTO docs VALUES (?, ?);" ["tls" "certificates and trust"])
(sqlite3/eval db "INSERT INTO docs VALUES (?, ?);" ["sqlite" "embedded database"])
(each r (sqlite3/eval db "SELECT title FROM docs WHERE docs MATCH :q ORDER BY bm25(docs);"
                      {:q "database"})
  (print (r :title)))
```

`chirp --help query` itself is built on this.
