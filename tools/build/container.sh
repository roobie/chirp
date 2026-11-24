#!/bin/sh
# Build chirp for a target inside the pinned container.
# Usage: container.sh <target> <outdir>   (target: a key of :targets in config.jdn)
# The outdir is mounted at its own host path so different outdirs mean
# different in-container paths.
set -eu

[ $# -eq 2 ] || { echo "usage: $0 <target> <outdir>" >&2; exit 2; }
target=$1
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$2"
out=$(cd "$2" && pwd)
# The derived image (alpine plus packages.txt), built by the build-image workflow.
image=$(sh "$root/tools/build/pin.sh" build-image)

exec docker run --rm \
  -v "$root:/chirp-src:ro" -v "$out:$out" \
  -e CHIRP_UID="$(id -u)" -e CHIRP_GID="$(id -g)" -e CHIRP_OUT="$out" \
  -e CHIRP_TARGET="$target" \
  "$image" sh /chirp-src/tools/build/container-inner.sh
