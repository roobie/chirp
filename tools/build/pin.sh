#!/bin/sh
# Print one value of pins.jdn, for the shell that runs before any janet exists.
# Usage: pin.sh <pin> [<key>]     pin.sh build-image     pin.sh janet commit
# It reads the file by its layout: one pin per line, string values only.
# pin.test.janet holds it to Janet's parse of the same file, so a layout this
# cannot follow fails a test, not a build.
set -eu

file=$(dirname "$0")/../../pins.jdn
case $# in
  1) value=$(sed -n "s/^[{ ]*:$1 \"\\([^\"]*\\)\".*/\\1/p" "$file") ;;
  2) value=$(sed -n "s/^[{ ]*:$1 {\\(.*\\)}.*/\\1/p" "$file" |
             sed -n "s/^\\(.* \\)\\{0,1\\}:$2 \"\\([^\"]*\\)\".*/\\2/p") ;;
  *) echo "usage: $0 <pin> [<key>]" >&2; exit 2 ;;
esac
[ -n "$value" ] || { echo "pin.sh: pins.jdn has no $*" >&2; exit 1; }
printf '%s\n' "$value"
