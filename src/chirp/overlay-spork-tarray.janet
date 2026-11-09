# Documentation for the bundled spork/tarray, whose docstring for new says only
# "Create new typed array." (#9). main.janet puts the binding over upstream's,
# named by :overlays in chirp.jdn. The value is upstream's own C function, so
# only the docs change. Drop this once spork documents tarray/new.
(import spork/tarray :as up)

(def new
  ``(tarray/new type size &opt stride offset tarray|buffer)

  Create a typed array of size elements of type: :uint8, :int8, :uint16,
  :int16, :uint32, :int32, :uint64, :int64, :float32 or :float64. stride
  (default 1) takes every stride-th element. Numbers are in the host's byte
  order, little-endian on every chirp target.

  The last argument gives the bytes:

  - none: new zeroed bytes.
  - a buffer or string, such as one from slurp: its bytes are copied, so
    writes to the array do not change it and later changes to it do not show.
    offset counts bytes into it.
  - a ta/buffer (from tarray/buffer): shared; offset counts bytes.
  - a typed array: its bytes are shared, and offset counts elements of its
    type. This is only right when that array starts at the first byte of its
    ta/buffer; otherwise spork computes a wrong start and raises
    "bad buffer size".

  Raises "bad buffer size" when offset plus the elements run past the bytes.``
  up/new)
