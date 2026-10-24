#!/bin/sh
# Cross-build chirp.exe twice in different directories, require identical
# binaries, then run the spike checks on it under Wine in a container.
# Usage: run-windows.sh [workdir]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=${1:-$root/build/spike-windows}
one=$work/one
two=$work/nested/two
target=windows-x64

# Only bin/ is compared and run, so by default the rest of each build tree
# (sources, toolchain, objects: about 1 GB) is dropped to keep disk use low.
# Set CHIRP_KEEP=1 to keep it for debugging.
build() {
  sh "$root/tools/build/container.sh" $target "$1"
  [ -n "${CHIRP_KEEP:-}" ] || find "$1" -mindepth 1 -maxdepth 1 ! -name bin -exec rm -rf {} +
}
build "$one"
build "$two"

a=$(sha256sum "$one/bin/chirp.exe" | cut -d' ' -f1)
b=$(sha256sum "$two/bin/chirp.exe" | cut -d' ' -f1)
echo "build one: $a"
echo "build two: $b"
[ "$a" = "$b" ] || { echo "FAIL: binaries differ" >&2; exit 1; }

base=$(sed -n 's/^{\{0,1\} *:image "\([^"]*\)".*/\1/p' "$root/pins.jdn")
docker build -q --build-arg "BASE=$base" -t chirp-wine:spike "$here/wine" >/dev/null
docker run --rm chirp-wine:spike apk info -v wine ca-certificates

# The embedded CA roots are not built yet, so verification uses the container's
# bundle through SSL_CERT_FILE; verification itself stays on.
docker run --rm \
  -v "$one/bin:/exe:ro" -v "$here:/checks:ro" \
  -e SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  chirp-wine:spike sh -eu -c '
    wine64 /exe/chirp.exe -v
    for t in zip https-get; do
      wine64 /exe/chirp.exe /checks/$t.janet
    done
    # Control: a self-signed certificate must be rejected, else the successful
    # request above proves nothing. (An empty SSL_CERT_FILE is no control: the
    # CA probing falls back to other system locations.)
    # Only a verify failure counts; a network error would pass otherwise.
    if out=$(wine64 /exe/chirp.exe /checks/https-get.janet https://self-signed.badssl.com/ 2>&1); then
      echo "FAIL: self-signed certificate was accepted" >&2; exit 1
    fi
    case "$out" in *"certificate verify failed"*) ;; *)
      echo "FAIL: control failed for another reason: $out" >&2; exit 1 ;;
    esac
    echo "ok verification: self-signed certificate rejected"
    echo "windows checks passed"'
