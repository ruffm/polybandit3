#!/usr/bin/env bash
# Assemble the GitHub Pages site that runs PolyBandit in the browser with v86.
# Usage: assemble-site.sh <image-dir> <image-prefix> <v86-bios-dir> <out-dir> [build-label]
#   <image-dir>     holds <prefix>.bzImage and <prefix>.rootfs.cpio.gz
#   <v86-bios-dir>  bios/ folder of a copy/v86 checkout (seabios.bin, vgabios.bin)
# Optional environment:
#   VERSION_NAME    shown in the page title, e.g. "v3.1" (default v3)
#   LAB_JSON        lab.json of the packaged lab; its form_url becomes a
#                   "Submit answers" button on the page
set -euo pipefail

IMAGES=${1:?image dir}
PREFIX=${2:?image prefix}
BIOS=${3:?v86 bios dir}
OUT=${4:?output dir}
LABEL=${5:-dev}
VERSION_NAME=${VERSION_NAME:-v3}
V86_VERSION=${V86_VERSION:-0.5.473}   # npm package with libv86.js + v86.wasm
HERE=$(cd "$(dirname "$0")/../.." && pwd)

mkdir -p "$OUT/v86" "$OUT/images"
cp "$HERE/web/index.html" "$OUT/index.html"
# The page always loads images/polybandit.*, whatever the variant's prefix.
cp "$IMAGES/$PREFIX.bzImage" "$OUT/images/polybandit.bzImage"
cp "$IMAGES/$PREFIX.rootfs.cpio.gz" "$OUT/images/polybandit.rootfs.cpio.gz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && npm pack "v86@$V86_VERSION" --silent >/dev/null && tar xzf v86-*.tgz)
cp "$tmp/package/build/libv86.js" "$tmp/package/build/v86.wasm" "$OUT/v86/"
cp "$tmp/package/LICENSE" "$OUT/v86/LICENSE-v86.txt"
cp "$BIOS/seabios.bin" "$BIOS/vgabios.bin" "$OUT/v86/"
cp "$BIOS/COPYING.LESSER" "$OUT/v86/COPYING.LESSER-seabios.txt"

python3 - "$OUT/build.json" "$LABEL" "$VERSION_NAME" "$V86_VERSION" "${LAB_JSON:-}" <<'PY'
import json, sys
out, label, version, v86, lab_json = sys.argv[1:6]
info = {"label": label, "version": version, "v86": v86}
if lab_json:
    url = json.load(open(lab_json)).get("form_url", "")
    if url.startswith("https://"):
        info["form_url"] = url
json.dump(info, open(out, "w"), indent=2)
PY
echo "Site assembled in $OUT ($(du -sh "$OUT" | cut -f1)):"
find "$OUT" -type f | sort | sed "s#^$OUT/#  #"
