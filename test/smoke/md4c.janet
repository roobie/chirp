# md4c is linked into the binary: Markdown renders to HTML, CommonMark by
# default, with GitHub's extensions on request.
(import md4c)

(defn- fails [f needle]
  (def [ok err] (protect (f)))
  (assert (not ok) (string "expected an error mentioning " needle))
  (assert (string/find needle (string err)) (string "error " err " lacks " needle)))

(def- table-md "| a | b |\n|---|---|\n| 1 | 2 |\n")

(assert (= "0.6.0" (md4c/version)) "version")
(assert (= "<h1>Hi</h1>\n<p><em>a</em> <code>b</code></p>\n" (md4c/to-html "# Hi\n\n*a* `b`\n")) "commonmark")
(assert (= "<p>x</p>\n" (md4c/to-html @"x")) "a buffer")
(assert (= "" (md4c/to-html "")) "empty input")
(assert (= "<p>x</p>\n" (md4c/to-html "\xEF\xBB\xBFx")) "a byte order mark is skipped")
(assert (not (string/find "<table>" (md4c/to-html table-md))) "no tables by default")
(assert (string/find "<table>" (md4c/to-html table-md {:tables true})) ":tables")
(assert (string/find "<table>" (md4c/to-html table-md {:github true})) ":github")
(assert (not (string/find "<table>" (md4c/to-html table-md {:github true :tables false}))) "a flag turned off after :github")
(assert (string/find "<del>" (md4c/to-html "~~x~~" {:github true})) "strikethrough")
(assert (string/find "<pre><code class=\"language-janet\">" (md4c/to-html "```janet\n(+ 1 2)\n```\n")) "fenced code")
(assert (string/find "&lt;" (md4c/to-html "`<`")) "code is escaped")
(assert (string/find "<b>" (md4c/to-html "<b>x</b>")) "raw HTML passes by default")
(assert (not (string/find "<b>" (md4c/to-html "<b>x</b>" {:no-html true}))) ":no-html")
(assert (string/find "<br />" (md4c/to-html "a  \nb" {:xhtml true})) ":xhtml")
(fails |(md4c/to-html "x" {:tabels true}) "unknown option")
(fails |(md4c/to-html "x" [:tables]) "table or a struct")
(def big (string/repeat "- item\n" 100000))
(assert (= 100000 (length (string/find-all "<li>" (md4c/to-html big)))) "a long document")
(print "ok")
