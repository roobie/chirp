# dev-proc examples

Units from chirp's own history. Their `STATE.md` files were deleted when they closed, and the commits linked here carry them. `dev-proc dig <unit id>` prints them again from a clone.

## A slice from start to finish: ordered-map

The slice that added `omap`, an insertion-ordered map, and ordered decoding to `json` and `yaml`.

- [`d3df7ff`](https://github.com/roobie/chirp/commit/d3df7ff) **initialize**: the slice is created with its purpose, scope and success criteria.
- [`88cc220`](https://github.com/roobie/chirp/commit/88cc220) **execute**: the gate to execute passes, because the slice has an owner and criteria that can be checked.
- [`ca05395`](https://github.com/roobie/chirp/commit/ca05395): the code, its smoke checks and the docs land together, and `STATE.md` changes in the same commit.
- [`a21fb7b`](https://github.com/roobie/chirp/commit/a21fb7b) **finalize**: CI is green, so the harvest is recorded and the unit's files are deleted in the same commit. It left three decisions, a learning and four backlog items.

The decisions are still in the repo, for example [D-PYFZFKJPCW3QPOTB](../.work/decisions/D-PYFZFKJPCW3QPOTB-omap-is-an-opaque-abstract-type-whose-copies-share.md), on why an `omap` is an opaque type. The learning [L-NYRT2RGVVAXTFIOF](../.work/learnings/L-NYRT2RGVVAXTFIOF-dev-proc-needs-a-chirp-that-bundles-omap.md) records something the slice found out the hard way.

## Cutting scope instead of letting a unit sprawl: cli-stdin

The cli-stdin slice set out to make `chirp -` and piped stdin run as a script. Part-way through, `-h`/`--help` turned out to be a separate job.

- [`13909ce`](https://github.com/roobie/chirp/commit/13909ce) **initialize**.
- [`5cd3367`](https://github.com/roobie/chirp/commit/5cd3367): `-h`/`--help` moves out of scope into a backlog item. The slice's criteria shrink to match.
- [`5add4ad`](https://github.com/roobie/chirp/commit/5add4ad) and [`a51473d`](https://github.com/roobie/chirp/commit/a51473d): the narrower slice ships and closes.
- [`db8cc62`](https://github.com/roobie/chirp/commit/db8cc62), [`ee6e9f5`](https://github.com/roobie/chirp/commit/ee6e9f5) and [`36f461b`](https://github.com/roobie/chirp/commit/36f461b): a day later the backlog item becomes the task cli-help, which goes through its own life and closes.

## A learning that pays off in the next unit: pcre2, then md4c

Bundling PCRE2 broke the final link with `duplicate symbol`. Every native module is linked into the one binary, and a function named `cfun_version` already existed in another one.

- [`f86f39c`](https://github.com/roobie/chirp/commit/f86f39c) **execute**: the pcre2 binding, with its function names prefixed.
- [`76266c9`](https://github.com/roobie/chirp/commit/76266c9) **finalize**: the decision [D-LGEWD4XRBUFOEIDS](../.work/decisions/D-LGEWD4XRBUFOEIDS-pcre2-is-a-chirp-owned-binding-with-counted-limits.md) and the learning [L-BVXC557ZOWPP4SN5](../.work/learnings/L-BVXC557ZOWPP4SN5-a-native-s-janet-fn-functions-are-global-symbols-s.md) are recorded.
- [`1d4ad8c`](https://github.com/roobie/chirp/commit/1d4ad8c): the next native, md4c, starts from that learning. Its binding's functions are prefixed, and md4c's own global symbols are renamed at build time, before a link has had the chance to fail.

## Backlog to slice, with a prerequisite split out: this site

- The site began as backlog item B-NEQ4LIZJMAZOYQLA. `dev-proc new slice gh-pages-site --from B-…` turned it into a slice, and its notes moved into `STATE.md`.
- While initializing, it became clear that chirp could not render Markdown to HTML. Rather than writing a private renderer inside the site, a separate slice bundled md4c first, in [`1d4ad8c`](https://github.com/roobie/chirp/commit/1d4ad8c). That one commit carries a `Work:` trailer for each of the two slices.
- Round-trip Markdown editing stayed in the backlog, now with notes on how md4c could support it.

## Porting the process to chirp: dev-proc-chirp

dev-proc was first written in Node and ported to Janet so the repo's own workflow needs nothing but chirp.

- [`20da2c4`](https://github.com/roobie/chirp/commit/20da2c4) **initialize**, [`8f700be`](https://github.com/roobie/chirp/commit/8f700be) the port, [`1f3b76e`](https://github.com/roobie/chirp/commit/1f3b76e) **finalize**. The gaps found along the way went into a backlog item instead of growing the task.
