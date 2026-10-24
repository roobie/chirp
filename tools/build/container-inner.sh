#!/bin/sh
# Runs inside the container: installs packages as root, then re-runs itself as
# the host uid to build janet and hand over to build.janet.
set -eu

src=/chirp-src

if [ "${1:-}" != build ]; then
  # Cross targets fetch and unpack the pinned zig, which needs curl and xz.
  extra=
  case "$CHIRP_TARGET" in linux-*) ;; *) extra="curl xz" ;; esac
  apk add --no-cache -q $(cat "$src/tools/build/packages.txt") $extra
  apk info -v | sort > "$CHIRP_OUT/apk-versions.txt"
  chown "$CHIRP_UID:$CHIRP_GID" "$CHIRP_OUT/apk-versions.txt"
  exec su-exec "$CHIRP_UID:$CHIRP_GID" sh "$src/tools/build/container-inner.sh" build
fi

export HOME="$CHIRP_OUT/home" TZ=UTC LC_ALL=C CHIRP_JOBS="$(nproc)"
mkdir -p "$HOME" "$CHIRP_OUT/src"

# Bootstrap janet from its pin; build.janet fetches everything else.
pin() { sed -n "s/.*:janet {.*:$1 \"\\([^\"]*\\)\".*/\\1/p" "$src/pins.jdn"; }
jd="$CHIRP_OUT/src/janet"
if [ ! -d "$jd/.git" ]; then
  git init -q "$jd"
  git -C "$jd" remote add origin "$(pin url)"
fi
commit=$(pin commit)
if [ "$(git -C "$jd" rev-parse -q --verify HEAD || true)" != "$commit" ]; then
  git -C "$jd" fetch -q --depth 1 origin "$commit"
  git -C "$jd" checkout -q --force --detach FETCH_HEAD
fi

cd "$jd"
make -j"$(nproc)" HAS_SHARED=0 CFLAGS=-O2 \
  JANET_BUILD="\\\"chirp-$(echo "$commit" | cut -c1-8)\\\"" \
  build/janet build/libjanet.a build/janet.h

# Empty seed pins janet's hash key to zero so images are reproducible.
JANET_HASHSEED= exec build/janet "$src/tools/build/build.janet" "$CHIRP_OUT" "$src"
