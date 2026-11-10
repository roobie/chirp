---
status: proposed
date: 2026-11-10
read_if:
  - adding or changing the wasm32-wasi target
  - a native module cannot be built for a target
  - a function raises 'not available in this build of chirp'
refs:
  - tools/build/build.janet#stubs-source
  - tools/build/build.janet#stub-main
  - tools/build/config.jdn
---

# D-T6TVFVI3SEQKWL7F A wasm build loads the host-built image by stubbing what it lacks under the same names

## Context
Task U-NEUAT66PBEWJRSWL: a wasm32-wasi chirp for a try-it page. The image is written once on the build machine by a full-featured janet and refers to C functions by name. A wasm janet compiles out the event loop, networking, processes, FFI and file watching, and the wasm target cannot link jsec (no OpenSSL) or spork/rawterm (needs the event loop and termios). Unmarshalling resolves a name the target lacks to nil without an error, so the image loads and then fails at the first call.

## Decision
Proposed: for a target marked `:stub-missing`, the build generates C that registers one raising function under every core function name of the build machine's janet that has no value on the target, and under every binding of each native the target does not link. The image's main calls it before building its unmarshal lookup. The image itself is unchanged.

## Why
The alternative, writing a second image with a wasm janet run under Node, would mean a second image build, a second module set to keep in step, and a Node dependency in the build. Stubs keep one image for every target: the spike showed it byte-identical in help output to the native build. The names come from the janet and natives the build already has, so no list is kept by hand. A raising stub turns a confusing `nil called` into a clear message, and existing docstrings stay.

## Consequences
- Code that calls a stubbed function fails at the call, not at import; the try-it page must say what is unavailable.
- The image main is patched by matching one line of spork's generated C; the build fails if spork changes it.
- Status stays proposed until the wasm target is taken up as a milestone.
