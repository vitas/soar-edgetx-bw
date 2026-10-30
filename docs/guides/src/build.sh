#!/bin/sh
# Builds the PDF guides in docs/guides from the HTML sources with headless Google Chrome.
# usage: build.sh en ru bg
set -eu

cd "$(dirname "$0")"

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PROFILE="$(mktemp -d "${TMPDIR:-/tmp}/soaredgetx-bw-pdf.XXXXXX")"
trap 'rm -rf "$PROFILE"' EXIT

for lang in "$@"; do
  "$CHROME" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
    --user-data-dir="$PROFILE" --no-pdf-header-footer --generate-pdf-document-outline \
    --print-to-pdf="../SoarEdgeTX-BW-MTail-$lang.pdf" "file://$PWD/mtail-$lang.html" 2>/dev/null
done
