# Replacement json/decode and json/encode for the bundled spork/json; main.janet
# puts them over the upstream bindings, named by :overlays in chirp.jdn. They add
# ordered maps (the omap module) and otherwise hand over to upstream's own C
# functions, so a script that does not use them sees spork's behaviour exactly.
(import spork/json :as up)
(import omap)
(import json-omap)

(defn decode
  ``Returns a janet object after parsing JSON. If keywords is truthy, string
  keys will be converted to keywords. If nils is truthy, null will become nil
  instead of the keyword :null. If ordered is truthy, objects become ordered
  maps (see the omap module) that hold their keys in the order written, so
  that json/encode writes them back in that order; without it this is spork's
  own decoder.

  Signature: (json/decode json-source &opt keywords nils ordered)``
  [src &opt keywords nils ordered]
  (if ordered
    (json-omap/decode src keywords nils)
    (up/decode src keywords nils)))

(defn- has-omap? [x depth]
  (cond
    (> depth 1024) false # upstream reports the depth
    (omap/omap? x) true
    (or (array? x) (tuple? x)) (truthy? (find |(has-omap? $ (inc depth)) x))
    (or (table? x) (struct? x)) (truthy? (find |(has-omap? $ (inc depth)) (values x)))
    false))

(defn- bytes-like? [x] (or (string? x) (symbol? x) (keyword? x) (buffer? x)))

# The encoder for a value that holds an omap: upstream's layout rules, with
# scalars (and so escaping and their errors) left to upstream's own encoder.
(defn- encode-one [x out tab nl depth]
  (when (> depth 1024) (error "encode error: recursed too deeply"))
  (def object? (or (omap/omap? x) (table? x) (struct? x)))
  (if-not (or object? (array? x) (tuple? x))
    (buffer/push out (up/encode x))
    (do
      (def items (cond (omap/omap? x) (omap/pairs x) object? (pairs x) x))
      (def sep (if (empty? tab) ":" ": "))
      (defn newline [level]
        (buffer/push out nl)
        (unless (empty? tab) (repeat level (buffer/push out tab))))
      (buffer/push out (if object? "{" "["))
      (var first? true)
      (each item items
        (if first? (set first? false) (buffer/push out ","))
        (newline (inc depth))
        (if object?
          (let [[k v] item]
            (unless (bytes-like? k) (error "encode error: object key must be a byte sequence"))
            (encode-one k out tab nl (inc depth))
            (buffer/push out sep)
            (encode-one v out tab nl (inc depth)))
          (encode-one item out tab nl (inc depth))))
      (unless first? (newline depth))
      (buffer/push out (if object? "}" "]")))))

(defn encode
  ``Encodes a janet value in JSON (utf-8). tab and newline are optional byte
  sequence which are used to format the output JSON. if buf is provided, the
  formated JSON is append to buf instead of a new buffer. Returns the modifed
  buffer. An ordered map (see the omap module) is written as an object with its
  keys in order; a value that holds none is encoded by spork's own encoder.

  Signature: (json/encode x &opt tab newline buf)``
  [x & args]
  # Upstream rejects an omap as an unsupported type, so a value without one never
  # pays for the walk below. A failed attempt may have written into buf.
  (def given (get args 2))
  (def mark (when (buffer? given) (length given)))
  (def [ok res] (protect (up/encode x ;args)))
  (cond
    ok res
    (not (has-omap? x 0)) (error res)
    (do
      (when mark (buffer/popn given (- (length given) mark)))
      (when (> (length args) 3) (error "expected 1 to 4 arguments"))
      (def [tab nl buf] [(get args 0) (get args 1) (get args 2)])
      (def tab* (if (nil? tab) "" tab))
      (def nl* (cond nl nl (nil? tab) "" "\r\n"))
      (unless (bytes-like? tab*) (errorf "bad slot #1, expected byte sequence, got %v" tab*))
      (unless (bytes-like? nl*) (errorf "bad slot #2, expected byte sequence, got %v" nl*))
      (def out (or buf @""))
      (encode-one x out tab* nl* 0)
      out)))
