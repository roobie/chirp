# Try chirp

This is chirp itself, compiled to WebAssembly and running in your browser: the same Janet, the same bundled modules and the same help as the [binary](../README.md), with nothing sent to a server. Edit the script and run it, or search the help below.

<form id="run-form" class="try">
<textarea id="code" spellcheck="false" autocapitalize="off" aria-label="Janet script"></textarea>
<div class="controls">
<button type="submit" id="run" disabled>Run</button>
<button type="button" id="stop" disabled>Stop</button>
<button type="button" id="share" disabled>Copy link</button>
<span id="status" role="status">Loading chirp.wasm…</span>
</div>
</form>
<pre id="output" class="output" aria-live="polite" hidden></pre>

## Search the help

The full offline help, as `chirp --help query` and `chirp --help read` give it: the help topics and the docstrings of Janet and of every bundled module.

<form id="help-form" class="search">
<input id="q" type="search" placeholder="words, such as: read a csv" aria-label="Search the help">
<button type="submit" id="search" disabled>Search</button>
</form>
<ul id="results" class="results" hidden></ul>
<pre id="topic" class="output" hidden></pre>

## What runs here and what does not

The page runs `chirp -` with the script as its standard input, once per run, so nothing carries over between runs and nothing is saved. Everything that computes works: Janet, PEGs, JSON, TOML, YAML, Markdown, HTML, regular expressions, gzip, SQLite and the rest. Anything that needs an operating system the browser does not give raises "not available in this build of chirp": files, subprocesses, the network and HTTPS, threads, the event loop and `os/cryptorand`. `os/sleep` blocks the run.

chirp.wasm is chirp's wasm32-wasi build target, built and checked with the release; its [license notices](NOTICES-wasm.txt) differ from the binaries' because it links neither OpenSSL nor a native libc.

<script type="module" src="try.mjs"></script>
