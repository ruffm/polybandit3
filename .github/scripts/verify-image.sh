#!/usr/bin/env bash

set -euo pipefail

ROOTFS=${1:?rootfs.cpio.gz}
REQUIRED=${2:?required-commands.txt}
EXTRA_COMMANDS="hexdump file base64 xxd tar gzip bzip2 strings md5sum sha256sum adduser passwd su awk sed grep cut tr find"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 - "$ROOTFS" "$tmp" <<'PY'
# Minimal newc cpio extractor (no host cpio needed, no device nodes created).
import gzip, os, stat, sys
src, dest = sys.argv[1], sys.argv[2]
data = gzip.open(src).read()
off = 0
while off < len(data):
    if data[off:off+6] not in (b"070701", b"070702"):
        off += 1; continue  # skip padding between concatenated archives
    h = data[off:off+110]
    f = lambda i: int(h[6+8*i:14+8*i], 16)
    mode, size, namesize = f(1), f(6), f(11)
    name = data[off+110:off+110+namesize-1].decode()
    off = (off + 110 + namesize + 3) & ~3
    body = data[off:off+size]
    off = (off + size + 3) & ~3
    if name == "TRAILER!!!": continue
    path = os.path.join(dest, name.lstrip("/"))
    if os.path.lexists(path) and not os.path.isdir(path): os.remove(path)
    if stat.S_ISDIR(mode): os.makedirs(path, exist_ok=True)
    elif stat.S_ISLNK(mode):
        os.makedirs(os.path.dirname(path), exist_ok=True); os.symlink(body.decode(), path)
    elif stat.S_ISREG(mode):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as fh: fh.write(body)
        os.chmod(path, mode & 0o777)
PY

fail=0
err() { echo "::error::$*"; fail=1; }

have_cmd() {
  local d
  for d in bin sbin usr/bin usr/sbin; do
    [ -e "$tmp/$d/$1" ] || [ -L "$tmp/$d/$1" ] && return 0
  done
  return 1
}

for c in $(tr -d '\r' < "$REQUIRED" | grep -v '^\s*#') $EXTRA_COMMANDS; do
  have_cmd "$c" || err "missing command in image: $c"
done

for f in .profile profile install.sh nextlevel prevlevel resources.sh; do
  [ -f "$tmp/root/$f" ] || err "missing /root/$f"
done
for n in $(seq 1 13); do
  [ -f "$tmp/root/bandit$n.sh" ] || err "missing /root/bandit$n.sh"
done
grep -q 'levelsetname="bandit"' "$tmp/root/install.sh" 2>/dev/null \
  || err "/root/install.sh is not the bandit installer"
[ ! -e "$tmp/root/installbandit.sh" ] || err "installbandit.sh should have been renamed to install.sh"

if crlf=$(grep -rlI $'\r' "$tmp/root" --include='*.sh' --include=.profile --include=profile --include=nextlevel --include=prevlevel); then
  err "CRLF line endings in: $crlf"
fi

[ "$fail" -eq 0 ] && echo "Image verification passed ($(find "$tmp/root" -type f | wc -l) payload files in /root)."
exit "$fail"
