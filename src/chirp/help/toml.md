# TOML

The `tomlin` module is a TOML parser written in Janet. It was added in chirp 0.2.0.

## Parse

`tomlin/toml->janet` takes TOML text and returns Janet data: tables with keyword keys, arrays, strings, numbers, booleans.

```janet
(import tomlin)

(def cfg (tomlin/toml->janet (slurp "config.toml")))
(print (cfg :title))
(print (get-in cfg [:owner :name]))
```

For this `config.toml`:

```toml
title = "chirp"
count = 42

[owner]
name = "wren"
```

## Integers are int/s64

TOML integers come back as `int/s64` values, not Janet numbers, so `=` does not equate them with a literal. Use `compare=`:

```janet
(print (= 42 (cfg :count)))          # false
(print (compare= 42 (cfg :count)))   # true
```

Floats are ordinary Janet numbers, so `=` works on them.
