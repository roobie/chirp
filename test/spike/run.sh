#!/bin/sh
# Build twice in different directories, require identical binaries, then run
# the spike checks with the result on this host. Usage: run.sh [workdir]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=${1:-$root/build/spike}
one=$work/one
two=$work/nested/two

sh "$root/tools/build/container.sh" linux-x64 "$one"
sh "$root/tools/build/container.sh" linux-x64 "$two"

a=$(sha256sum "$one/bin/chirp" | cut -d' ' -f1)
b=$(sha256sum "$two/bin/chirp" | cut -d' ' -f1)
echo "build one: $a"
echo "build two: $b"
[ "$a" = "$b" ] || { echo "FAIL: binaries differ" >&2; exit 1; }

cd "$work"
for t in zip https-get https-server; do
  "$one/bin/chirp" "$here/$t.janet"
done
echo "all spike checks passed"
