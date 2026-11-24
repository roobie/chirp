# What upstream has published since the pins in pins.jdn were set: for a tagged
# pin the tags after its own, for an untagged one whether its branch has moved,
# for zig the releases after the pinned one, and the recent items of the feeds
# in watch.jdn. It only reads: nothing is written, here or upstream.
#   chirp tools/pins/watch.janet [--days N] [--root DIR]
# Exits 0 when everything could be read, whatever it found, and 1 otherwise.

(import spork-https :as https)

# Tags ------------------------------------------------------------------------

(def- numbers-peg
  (peg/compile ~{:num (/ (<- :d+) ,scan-number)
                 :main (* (group (* :num (any (* "." :num)))) (<- (any 1)))}))

(defn- letter? [c] (or (<= (chr "a") c (chr "z")) (<= (chr "A") c (chr "Z"))))

(defn parse-tag
  "[prefix numbers suffix] of a tag such as pcre2-10.49 or v0.2.0-interim1, or
  nil when it holds no version. The version starts at the first digit that
  does not belong to a name: one at the start, after a lone v, or after
  something that is neither a letter nor a digit."
  [tag]
  (var at nil)
  (for i 0 (length tag)
    (def c (tag i))
    (when (and (nil? at) (<= (chr "0") c (chr "9"))
               (or (zero? i)
                   (and (= i 1) (index-of (tag 0) "vV"))
                   (let [p (tag (dec i))] (not (or (letter? p) (<= (chr "0") p (chr "9")))))))
      (set at i)))
  (when at
    (def [nums suffix] (peg/match numbers-peg tag at))
    [(string/slice tag 0 at) (tuple ;nums) suffix]))

(defn- compare-numbers [a b]
  (var res 0)
  (for i 0 (max (length a) (length b))
    (when (zero? res)
      (set res (compare (get a i 0) (get b i 0)))))
  res)

(defn newer-tags
  "The tags that come after pinned, oldest first. Only tags spelled like it
  count (the same text before the number), so another product's tags in the
  same repository do not. A tag with text after its number (-rc1, -interim1)
  is listed when its number is not lower: whether such a tag is before or
  after the plain one is the project's own convention, so the reader decides."
  [pinned tags]
  (def [prefix nums suffix] (or (parse-tag pinned) (errorf "the pinned tag %s holds no number" pinned)))
  (def res @[])
  (each t tags
    (when-let [[p n s] (parse-tag t)]
      (def c (compare-numbers n nums))
      (when (and (= p prefix) (not= t pinned)
                 (or (pos? c) (and (zero? c) (not= s "") (not= s suffix))))
        (array/push res [n s t]))))
  # Within one number the suffixed tags come first, as pre-releases do.
  (sort res (fn [[an as] [bn bs]]
              (def c (compare-numbers an bn))
              (cond (not (zero? c)) (neg? c)
                    (= as "") false
                    (= bs "") true
                    (< as bs))))
  (map last res))

# Feeds -----------------------------------------------------------------------

(def- months {"Jan" 0 "Feb" 1 "Mar" 2 "Apr" 3 "May" 4 "Jun" 5
              "Jul" 6 "Aug" 7 "Sep" 8 "Oct" 9 "Nov" 10 "Dec" 11})

(def- date-peg
  (peg/compile ~{:n (/ (<- :d+) ,scan-number)
                 :main (* (any (if-not :d 1)) :n " " (<- 3) " " :n " " :n ":" :n ":" :n)}))

(defn rss-time
  "Seconds since the epoch of an RSS pubDate given in UTC, such as
  `Thu, 19 Nov 2026 23:47:40 +0000`, or nil."
  [text]
  (when-let [[d mon y h mi s] (peg/match date-peg text)
             m (months mon)]
    (os/mktime {:year y :month m :month-day (dec d) :hours h :minutes mi :seconds s})))

(defn- unescape [s]
  (->> s
       (string/replace-all "&quot;" "\"") (string/replace-all "&#39;" "'")
       (string/replace-all "&lt;" "<") (string/replace-all "&gt;" ">")
       (string/replace-all "&amp;" "&")))

(defn- headline
  "The first line of a title, cut to a length that fits a terminal."
  [s]
  (def line (first (string/split "\n" (string/trim s))))
  (if (> (length line) 110) (string (string/slice line 0 107) "...") line))

(defn- element [name text]
  (def open (string "<" name ">"))
  (when-let [a (string/find open text)
             b (string/find (string "</" name ">") text a)]
    (string/slice text (+ a (length open)) b)))

(defn rss-items
  "The items of an RSS document as {:title :link :time}, in its order."
  [xml]
  (def res @[])
  (var at 0)
  (while (def a (string/find "<item>" xml at))
    (def b (or (string/find "</item>" xml a) (length xml)))
    (def item (string/slice xml a b))
    (array/push res {:title (headline (unescape (or (element "title" item) "")))
                     :link (or (element "link" item) "")
                     :time (rss-time (or (element "pubDate" item) ""))})
    (set at b))
  res)

(defn since
  "The items at or after time. One whose date could not be read is kept."
  [items time]
  (filter |(or (nil? ($ :time)) (>= ($ :time) time)) items))

# Reading ---------------------------------------------------------------------

(defn- git-refs
  "{ref commit} for url, of the refs matching the patterns."
  [url & patterns]
  (def proc (os/spawn ["git" "ls-remote" url ;patterns] :p {:out :pipe :err :pipe}))
  (def out (ev/read (proc :out) :all))
  (def err (ev/read (proc :err) :all))
  (unless (zero? (os/proc-wait proc)) (errorf "git ls-remote %s: %s" url (string/trim (string (or err "")))))
  (tabseq [line :in (string/split "\n" (string (or out ""))) :when (not (empty? line))
           :let [[commit ref] (string/split "\t" line)]]
    ref commit))

(defn- fetch [url]
  (def res (https/request "GET" url :max-redirects 10))
  (unless (= 200 (res :status)) (errorf "HTTP %d" (res :status)))
  (string (res :body)))

(defn- short [commit] (string/slice commit 0 (min 10 (length commit))))

(defn- watch-pin [name pin branches]
  (cond
    (and (pin :tag) (pin :url))
    (let [refs (git-refs (pin :url) "refs/tags/*")
          # An annotated tag's commit is under name^{}; either spelling is the tag.
          tags (distinct (seq [r :in (keys refs)]
                           (string/replace "^{}" "" (string/slice r (length "refs/tags/")))))
          newer (newer-tags (pin :tag) tags)]
      (if (empty? newer)
        (printf "%-12s %s  current" name (pin :tag))
        (printf "%-12s %s  newer: %s" name (pin :tag) (string/join newer " "))))

    (and (pin :commit) (pin :url))
    (let [branch (get branches name)
          ref (if branch (string "refs/heads/" branch) "HEAD")
          head (get (git-refs (pin :url) ref) ref)]
      (cond
        (nil? head) (errorf "%s has no %s" (pin :url) ref)
        (= head (pin :commit)) (printf "%-12s %s  current (%s)" name (short (pin :commit)) (or branch "default branch"))
        (printf "%-12s %s  moved: %s is at %s" name (short (pin :commit)) (or branch "the default branch") (short head))))

    (= name :zig)
    (let [index (fetch "https://ziglang.org/download/index.json")
          # The keys of the index are the versions; no JSON reader is needed for them.
          versions (map first (peg/match ~(any (+ (* "\n  \"" (group (<- (to "\""))) "\": {") 1)) index))
          newer (newer-tags (pin :version) versions)]
      (if (empty? newer)
        (printf "%-12s %s  current" name (pin :version))
        (printf "%-12s %s  newer: %s" name (pin :version) (string/join newer " "))))

    (printf "%-12s not watched (%s)" name
            (if (pin :version) (string "version " (pin :version)) "an image digest"))))

(defn main [_ & args]
  (var root ".")
  (var days 30)
  (var i 0)
  (defn usage [] (eprint "usage: watch.janet [--days N] [--root DIR]") (os/exit 2))
  (while (< i (length args))
    (case (args i)
      "--root" (set root (or (get args (++ i)) (usage)))
      "--days" (set days (or (scan-number (get args (++ i) "")) (usage)))
      (usage))
    (++ i))
  (def pins (parse (slurp (string root "/pins.jdn"))))
  (def data (parse (slurp (string root "/tools/pins/watch.jdn"))))
  (var unread 0)
  (defn attempt [what f]
    (def [ok err] (protect (f)))
    (unless ok (++ unread) (printf "%-12s could not be read: %s" what err)))

  (print "Pins")
  (each name (sorted (keys pins))
    (def pin (pins name))
    (def pin (if (string? pin) {} pin))
    (attempt name |(watch-pin name pin (get data :branches {}))))

  (def from (- (os/time) (* days 86400)))
  (printf "\nFeeds, the last %d days" days)
  (each {:name name :url url} (data :feeds)
    (attempt name
             (fn []
               (def items (since (rss-items (fetch url)) from))
               (if (empty? items)
                 (print name ": nothing new")
                 (do (print name ":")
                   (each {:title title :link link :time time} items
                     (def d (when time (os/date time)))
                     (printf "  %s  %s\n              %s"
                             (if d (string/format "%d-%02d-%02d" (d :year) (inc (d :month)) (inc (d :month-day))) "????-??-??")
                             title link)))))))
  (when (pos? unread)
    (eprintf "\nwatch: %d source(s) could not be read" unread)
    (os/exit 1)))
