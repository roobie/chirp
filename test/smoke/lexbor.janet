# lexbor is linked into the binary: HTML parses into a document that CSS
# selectors query, and nodes give their text, attributes and HTML.
(import lexbor)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

(def- page
  ``<!DOCTYPE html>
  <html lang=en><head><title>T</title></head>
  <body>
  <nav><a href="/">Home</a> <a href="/docs/" class="here">Docs</a></nav>
  <main id=m><h1>Hi <em>there</em></h1>
  <p>one<p>two <a href="#x">x</a>
  <input disabled data-X="1">
  </main>``)

(assert (= "3.0.1" (lexbor/version)) "version")
(def d (lexbor/parse page))
(assert (= :lexbor/document (type d)) "a document")
(assert (= :lexbor/document (type (lexbor/parse @""))) "a buffer, and empty input")

(def links (lexbor/select d "a[href]"))
(assert (deep= @["/" "/docs/" "#x"] (map |(lexbor/attr $ "href") links)) "select, in document order")
(assert (= 2 (length (lexbor/select d "nav a, a.here"))) "a node matched twice is returned once")
(assert (= "Docs" (lexbor/text (lexbor/select-first d "nav .here"))) "select-first")
(assert (nil? (lexbor/select-first d "table")) "no match is nil")
(assert (empty? (lexbor/select d "table")) "no match is empty")

(def m (lexbor/select-first d "main"))
(assert (= 1 (length (lexbor/select m "a"))) "select under a node")
(assert (empty? (lexbor/select m "main")) "the root is not a match")
(assert (= 2 (length (lexbor/select m "p"))) "unclosed <p> is repaired")
(assert (= (lexbor/select-first d "#m") m) "two handles on one node are equal")
(assert (= 1 (length (distinct [m (lexbor/select-first d "main")]))) "and hash alike")

(assert (= "Hi there" (lexbor/text (lexbor/select-first d "h1"))) "text")
(assert (string/find "Home" (lexbor/text d)) "text of a document")
(assert (= "main" (lexbor/tag m)) "tag")
(assert (= "html" (lexbor/tag d)) "tag of a document")
(assert (= "m" (lexbor/attr m "ID")) "attribute names ignore case")
(assert (nil? (lexbor/attr m "class")) "a missing attribute is nil")
(def input (lexbor/select-first d "input[disabled]"))
(assert (= "" (lexbor/attr input "disabled")) "an attribute without a value")
(assert (= {"disabled" "" "data-x" "1"} (lexbor/attrs input)) "attrs")
(assert (= "en" (lexbor/attr d "lang")) "a document stands for <html>")

(assert (= "<h1>Hi <em>there</em></h1>" (lexbor/html (lexbor/select-first d "h1"))) "html")
(assert (= "Hi <em>there</em>" (lexbor/inner-html (lexbor/select-first d "h1"))) "inner-html")
(assert (string/has-prefix? "<!DOCTYPE html><html lang=\"en\">" (lexbor/html d)) "html of a document")

(fails |(lexbor/select d "a[") "bad selector")
(fails |(lexbor/select "<p>" "p") "expected a document or a node")

# A node keeps its document alive after the document itself is dropped.
(def kept (lexbor/select-first (lexbor/parse "<p class=k>kept</p>") "p"))
(gccollect)
(assert (= "kept" (lexbor/text kept)) "a node outlives its document's binding")

(def big (lexbor/parse (string "<ul>" (string/repeat "<li><a href=x>i</a>" 100000) "</ul>")))
(assert (= 100000 (length (lexbor/select big "li > a[href]"))) "a long document")
(print "ok")
