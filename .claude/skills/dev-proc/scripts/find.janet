# Ranks durable records (decisions, learnings) against a free-text "what I am about to do" query.
# SQLite FTS5 (porter stemmer, bm25) does the matching; nothing here stems or scores by hand.
# Records are tables { :id :kind :title :read-if [string ...] }.
(import sqlite3)

(def- cue-weight 2)
(def- title-weight 1)

# Ref-style cues (`crates/sim/src/rng.rs#Rng`) locate code rather than describe a reason to read,
# and their path segments would match nearly every record.
(defn- ref-cue? [cue]
  (and (not (find |(or (= $ 32) (<= 9 $ 13)) cue))
       (or (string/find "/" cue) (string/find "#" cue))
       true))

# FTS5 has no stopword list, and "a" or "to" would match every cue.
(def- stopwords
  (tabseq [w :in (string/split " " "a an the and or but to of in on at for from by with without into about as is are was be been it its this that these those i me my we our you your when before after while how what why which do does not no")]
    w true))

# Distinct lowercase alphanumeric words, so FTS5 syntax in user input is never interpreted.
(defn words [text]
  (def seen @{})
  (def out @[])
  (each w (or (peg/match ~(any (+ (<- (some (+ (range "az") (range "09")))) 1)) (string/ascii-lower text)) [])
    (unless (or (seen w) (stopwords w) (< (length w) 2))
      (put seen w true)
      (array/push out w)))
  out)

# Returns matching records, best first: records merged with { :cues :matched :score }.
# Each query word is searched on its own: a cue row hit counts double a title row hit, and the
# bm25 weight makes a word found in few rows worth more than one found in many.
(defn find-records [records query]
  (def ws (words query))
  (when (empty? ws) (break @[]))
  (def db (sqlite3/open ":memory:"))
  (defer (sqlite3/close db)
    (sqlite3/eval db "CREATE VIRTUAL TABLE t USING fts5(text, ix UNINDEXED, kind UNINDEXED, tokenize = 'porter unicode61');")
    (sqlite3/eval db "BEGIN;")
    (eachp [i r] records
      (sqlite3/eval db "INSERT INTO t VALUES (?, ?, 'title');" [(r :title) i])
      (each c (r :read-if)
        (unless (ref-cue? c) (sqlite3/eval db "INSERT INTO t VALUES (?, ?, 'cue');" [c i]))))
    (sqlite3/eval db "COMMIT;")
    (def score @{})
    (def matched @{})
    (def cues @{})
    (each w ws
      (each row (sqlite3/eval db "SELECT text, ix, kind, bm25(t) AS b FROM t WHERE t MATCH :q;" {:q (string "\"" w "\"")})
        (def i (row :ix))
        (def cue? (= (row :kind) "cue"))
        (put score i (+ (get score i 0) (* (if cue? cue-weight title-weight) (- (row :b)))))
        (unless (find |(= $ w) (get matched i [])) (put matched i (array/push (get matched i @[]) w)))
        (when cue? (unless (find |(= $ (row :text)) (get cues i [])) (put cues i (array/push (get cues i @[]) (row :text)))))))
    (def hits
      (seq [[i s] :pairs score]
        (merge (records i) {:cues (filter |(find (fn [c] (= c $)) (get cues i [])) (get-in records [i :read-if])) :matched (matched i)
                            :score (/ (math/floor (+ (* s 100) 0.5)) 100) :raw s})))
    (sort hits (fn [a b] (cond (> (a :raw) (b :raw)) true
                               (< (a :raw) (b :raw)) false
                               (< (a :id) (b :id)))))))
