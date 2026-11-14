#!/usr/bin/env bash
# Assemble the GitHub Pages site that runs PolyBandit in the browser with v86.
# Usage: assemble-site.sh <image-dir> <v86-bios-dir> <out-dir> [build-label]
#   <image-dir>     holds polybandit3.bzImage and polybandit3.rootfs.cpio.gz
#   <v86-bios-dir>  bios/ folder of a copy/v86 checkout (seabios.bin, vgabios.bin)
set -euo pipefail

IMAGES=${1:?image dir}
BIOS=${2:?v86 bios dir}
OUT=${3:?output dir}
LABEL=${4:-dev}
V86_VERSION=${V86_VERSION:-0.5.473}   # npm package with libv86.js + v86.wasm
HERE=$(cd "$(dirname "$0")/../.." && pwd)

mkdir -p "$OUT/v86" "$OUT/images"
cp "$HERE/web/index.html" "$OUT/index.html"
cp "$IMAGES/polybandit3.bzImage" "$IMAGES/polybandit3.rootfs.cpio.gz" "$OUT/images/"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && npm pack "v86@$V86_VERSION" --silent >/dev/null && tar xzf v86-*.tgz)
cp "$tmp/package/build/libv86.js" "$tmp/package/build/v86.wasm" "$OUT/v86/"
cp "$tmp/package/LICENSE" "$OUT/v86/LICENSE-v86.txt"
cp "$BIOS/seabios.bin" "$BIOS/vgabios.bin" "$OUT/v86/"
cp "$BIOS/COPYING.LESSER" "$OUT/v86/COPYING.LESSER-seabios.txt"

printf '{"label": "%s", "v86": "%s"}\n' "$LABEL" "$V86_VERSION" > "$OUT/build.json"
echo "Site assembled in $OUT ($(du -sh "$OUT" | cut -f1)):"
find "$OUT" -type f | sort | sed "s#^$OUT/#  #"
