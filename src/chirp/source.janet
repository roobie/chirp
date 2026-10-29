# Source text for the help entries. A binding's :source-map says where it was
# defined; locator turns that into the definition's text while the image is built,
# so the binary carries it and reads nothing at runtime.

(defn- read-lines [path]
  (def [ok text] (protect (slurp path)))
  # Some upstream files use CRLF; the baked text is LF whatever the source was.
  (when (and ok (= :file (os/stat path :mode)))
    (string/split "\n" (string/replace-all "\r\n" "\n" text))))

# The top-level form that starts at (line, col): feed the parser line by line
# until it holds a value. Anything unparsable is not a definition we can show.
(defn- janet-form [lines line col]
  (def p (parser/new))
  (def buf @"")
  (var i (dec line))
  (while (and (< i (length lines)) (not (parser/has-more p))
              (not= :error (parser/status p)))
    (def l (lines i))
    (def part (string (if (= i (dec line)) (string/slice l (min (length l) (dec col))) l) "\n"))
    (buffer/push buf part)
    (parser/consume p part)
    (++ i))
  (when (parser/has-more p) (string/trimr buf)))

# A C function runs from its JANET_CORE_FN line to the first line that is just `}`.
(defn- c-function [lines line]
  (var i (dec line))
  (while (and (< i (length lines)) (not= "}" (lines i))) (++ i))
  (when (< i (length lines))
    (string/join (array/slice lines (dec line) (inc i)) "\n")))

(defn locator
  "A function from a binding's :source-map to [source source-at], or nil when
  the definition cannot be found. `rules` is a list of {:prefix :dir :show
  :base}: a source-map file starting with :prefix lives at :dir plus the rest
  of the name, under the root named by :base in `bases` (default :out), and is
  shown as :show plus the rest. The first matching rule wins."
  [rules bases]
  (def files @{})
  (def found @{})
  (defn lines-of [path]
    (unless (has-key? files path) (put files path (read-lines path)))
    (files path))
  (defn lookup [file line col]
    (when-let [rule (find |(string/has-prefix? ($ :prefix) file) rules)]
      (def rest (string/slice file (length (rule :prefix))))
      (when-let [lines (lines-of (string (bases (get rule :base :out)) (rule :dir) rest))
                 text (if (string/has-suffix? ".c" file)
                        (c-function lines line)
                        (janet-form lines line col))]
        [text (string (rule :show) rest ":" line)])))
  (fn [source-map]
    (when (and (tuple? source-map) (= 3 (length source-map))
               (string? (source-map 0)) (int? (source-map 1)) (int? (source-map 2))
               (pos? (source-map 1)) (pos? (source-map 2)))
      (def [file line col] source-map)
      # Bindings from one definition share one string in the image.
      (def key [file line col])
      (unless (has-key? found key) (put found key (lookup file line col)))
      (found key))))
