#!/bin/sh
# Build chirp for linux inside the pinned container. Usage: linux.sh <outdir>
# The outdir is mounted at its own host path so different outdirs mean
# different in-container paths.
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <outdir>" >&2; exit 2; }
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$1"
out=$(cd "$1" && pwd)
image=$(sed -n 's/^{\{0,1\} *:image "\([^"]*\)".*/\1/p' "$root/pins.jdn")

exec docker run --rm \
  -v "$root:/chirp-src:ro" -v "$out:$out" \
  -e CHIRP_UID="$(id -u)" -e CHIRP_GID="$(id -g)" -e CHIRP_OUT="$out" \
  "$image" sh /chirp-src/tools/build/linux-inner.sh
