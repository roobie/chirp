# pcre2 is linked into the binary: Perl-style patterns match, replace and split,
# and a runaway pattern stops at its limit with an error instead of hanging.
(import pcre2)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

(defn- matching []
  (assert (string/has-prefix? "10." (pcre2/version)) "version")
  (assert (deep= (pcre2/match "(\\d+)-(\\d+)" "tel 12-345 x") {0 "12-345" 1 "12" 2 "345"}) "groups")
  (assert (deep= (pcre2/match "(?<year>\\d{4})" "in 2026") {0 "2026" 1 "2026" :year "2026"}) "named group")
  (assert (deep= (pcre2/match "(a)|(b)" "b") {0 "b" 2 "b"}) "an unset group has no key")
  (assert (nil? (pcre2/match "x" "abc")) "no match")
  (assert (deep= (pcre2/match "a" "aXa" {:start 1}) {0 "a"}) ":start")
  (assert (pcre2/match "ABC" "xabc" {:caseless true}) ":caseless")
  (assert (= "\xC3\xA9\xC3\xA9" ((pcre2/match "é+" "caféé!") 0)) "UTF-8 subjects")
  (assert (= "\xFF" ((pcre2/match "\xFF" "\xFF" {:utf false}) 0)) "bytes mode")
  (fails |(pcre2/match "a" "\xFF") "UTF-8")
  (fails |(pcre2/compile "(") "missing closing parenthesis")
  (fails |(pcre2/match (pcre2/compile "a") "a" {:caseless true}) "pcre2/compile"))

(defn- many []
  (def re (pcre2/compile "\\w+"))
  (assert (deep= (map |($ 0) (pcre2/find-all re "ab cd  ef")) @["ab" "cd" "ef"]) "find-all")
  (assert (deep= (map |($ 0) (pcre2/find-all "x*" "axxb")) @["" "xx" "" ""]) "find-all with empty matches")
  (assert (= "world hello" (pcre2/replace "(\\w+) (\\w+)" "hello world" "$2 $1")) "replace")
  (assert (= "a<1>b<2>" (pcre2/replace-all "(?<d>\\d)" "a1b2" "<${d}>")) "replace-all with a named group")
  (assert (= "[a][b]" (pcre2/replace-all "(a)|(b)" "ab" "[$1$2]")) "replace with unset groups")
  (fails |(pcre2/replace "a" "a" "$9") "unknown substring")
  (assert (deep= (pcre2/split ",\\s*" "a, b,c") @["a" "b" "c"]) "split")
  (assert (deep= (pcre2/split "," ",a,") @["" "a" ""]) "split keeps empty edge pieces")
  (assert (deep= (pcre2/split "," "a,b,c,d" {:max 2}) @["a" "b" "c,d"]) "split :max"))

(defn- limits []
  (def subject (string (string/repeat "a" 40) "!"))
  (def start (os/clock))
  (fails |(pcre2/match "^(a+)+$" subject) "match limit")
  (assert (< (- (os/clock) start) 5) "a runaway pattern stops quickly")
  (fails |(pcre2/match "^(a+)+$" subject {:match-limit 1000}) "match limit")
  (assert (= "z" ((pcre2/match "z$" (string (string/repeat "a" 2000000) "z")) 0)) "a long subject"))

(matching)
(many)
(limits)
(print "ok")
