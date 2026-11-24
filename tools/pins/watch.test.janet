# Run from the repo root: chirp tools/pins/watch.test.janet
# The ordering and the parsing; nothing here reaches the network.
(import ./watch)

(var failures 0)
(defn- check [name got want]
  (unless (deep= got want)
    (++ failures)
    (eprintf "FAIL %s\n  got:  %q\n  want: %q" name got want)))

(check "a plain tag" (watch/parse-tag "0.2.5") ["" [0 2 5] ""])
(check "a prefixed tag" (watch/parse-tag "pcre2-10.49") ["pcre2-" [10 49] ""])
(check "a tag with a suffix" (watch/parse-tag "v0.2.0-interim1") ["v" [0 2 0] "-interim1"])
(check "no number" (watch/parse-tag "latest") nil)
(check "a digit inside a name is not the version" (watch/parse-tag "sha3") nil)
(check "an older spelling" (watch/parse-tag "OpenSSL_1_1_1w") ["OpenSSL_" [1] "_1_1w"])

(check "numbers order as numbers, not as text"
       (watch/newer-tags "v1.9.0" ["v1.10.0" "v1.9.1" "v1.9.0" "v1.8.9" "v2.0.0"])
       @["v1.9.1" "v1.10.0" "v2.0.0"])
(check "a missing part counts as zero"
       (watch/newer-tags "pcre2-10.49" ["pcre2-10.49.1" "pcre2-10.5" "pcre2-11"])
       @["pcre2-10.49.1" "pcre2-11"])
(check "only tags spelled like the pin count"
       (watch/newer-tags "openssl-3.6.5" ["OpenSSL_1_1_1w" "openssl-3.6.6" "v9.9.9" "openssl-4.0.0"])
       @["openssl-3.6.6" "openssl-4.0.0"])
(check "a suffixed tag of a higher or equal number is listed, of a lower one not"
       (watch/newer-tags "v0.2.0" ["v0.2.0-interim1" "v0.3.0-rc1" "v0.1.9-rc2"])
       @["v0.2.0-interim1" "v0.3.0-rc1"])
(check "from a suffixed pin, the plain tag and the other suffixes"
       (watch/newer-tags "v0.2.0-interim1" ["v0.2.0-interim1" "v0.2.0-interim2" "v0.2.0"])
       @["v0.2.0-interim2"])
(check "within one number, suffixed tags come before the plain one"
       (watch/newer-tags "0.2.5" ["0.2.6" "0.2.6-rc.1" "0.2.7"])
       @["0.2.6-rc.1" "0.2.6" "0.2.7"])
(check "nothing newer" (watch/newer-tags "0.2.5" ["0.2.5" "0.2.4" "0.1.0"]) @[])
(check "a pinned tag without a number is an error"
       (first (protect (watch/newer-tags "stable" ["v1"]))) false)

(check "a pubDate in UTC" (watch/rss-time "Thu, 19 Nov 2026 23:47:40 +0000")
       (os/mktime {:year 2026 :month 10 :month-day 18 :hours 23 :minutes 47 :seconds 40}))
(check "the epoch" (watch/rss-time "Thu, 1 Jan 1970 00:00:00 +0000") 0)
(check "not a date" (watch/rss-time "soon") nil)

(def xml
  (string "<rss><channel><title>the channel</title><pubDate>Tue, 24 Nov 2026 15:03:55 +0000</pubDate>\n"
          "<item><title>Add tag &quot;v1&quot; &amp; more</title><link>https://x.test/1</link>"
          "<pubDate>Thu, 19 Nov 2026 23:47:40 +0000</pubDate></item>\n"
          "<item><title>older</title><link>https://x.test/2</link>"
          "<pubDate>Sun, 18 Oct 2026 17:32:52 +0000</pubDate></item>\n"
          "<item><title>undated</title><link>https://x.test/3</link></item>\n"
          "</channel></rss>"))
(def items (watch/rss-items xml))
(check "items, with entities read" (map |($ :title) items) @["Add tag \"v1\" & more" "older" "undated"])
(check "a long title is cut to its first line"
       ((first (watch/rss-items (string "<item><title>first line\nsecond " (string/repeat "x" 200) "</title></item>"))) :title)
       "first line")
(check "and to a width"
       (length ((first (watch/rss-items (string "<item><title>" (string/repeat "x" 200) "</title></item>"))) :title))
       110)
(check "links" (map |($ :link) items) @["https://x.test/1" "https://x.test/2" "https://x.test/3"])
(check "since keeps the newer and the undated"
       (map |($ :title) (watch/since items (watch/rss-time "Sun, 1 Nov 2026 00:00:00 +0000")))
       @["Add tag \"v1\" & more" "undated"])
(check "no items" (watch/rss-items "<rss><channel></channel></rss>") @[])

(when (pos? failures)
  (eprintf "watch tests: %d failed" failures)
  (os/exit 1))
(print "watch tests: ok")
