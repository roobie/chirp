---
status: accepted
date: 2026-10-24
read_if:
  - choosing or replacing the TLS backend
  - build time or binary size concerns
refs:
---

# D-GNHGVHYBQ7SLBAIU TLS via llmII/jsec with static OpenSSL 3

## Context
Stock Janet has no TLS. TLS has to plug into Janet's `ev` streams so that spork's HTTP code can use it unchanged.

## Decision
Use llmII/jsec for TLS, statically linked against OpenSSL 3.

## Why
jsec already exposes TLS as an `ev`-compatible stream (`ev/read`, `:write`, `:chunk`, `:close`). That is the hard part to design, and with mbedTLS we would have to build it ourselves. jsec is ISC-licensed, actively maintained, and verified on 11 platforms.

## Consequences
Static OpenSSL makes the binary bigger and the build slow, so the OpenSSL build is cached by its pin.
