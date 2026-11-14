#!/usr/bin/env bash
# Static checks on a packaged PolyBandit rootfs.cpio.gz:
#   - every command in the config set's required-commands.txt and the ones the
#     installers and levels call exist
#   - /root holds exactly the files of the packaged payload folder (byte for
#     byte, with the installer renamed to install.sh)
#   - no CI files or other labs in /root, no CRLF line endings
#   - flavor-specific checks (v3: bandit installer waits for its generators)
# Usage: verify-image.sh <rootfs.cpio.gz> <required-commands.txt> <payload-dir> <installer> <flavor>
set -euo pipefail

ROOTFS=${1:?rootfs.cpio.gz}
REQUIRED=${2:?required-commands.txt}
PAYLOAD=${3:?payload dir}
INSTALLER=${4:?installer file name}
FLAVOR=${5:?flavor (v3 or v31)}
# Union of what the bandit levels and both installers call.
EXTRA_COMMANDS="hexdump file base64 xxd tar gzip bzip2 strings md5sum sha256sum adduser passwd su awk sed grep cut tr find
  basename dirname cat chmod chown cp date head id mkdir mv pwd rm sleep sort tail touch uniq wc"

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

# Every payload file must be in /root unchanged (installer renamed to install.sh).
checked=0
while IFS= read -r -d '' src; do
  rel=${src#"$PAYLOAD"/}
  dst=$rel; [ "$rel" = "$INSTALLER" ] && dst=install.sh
  if [ ! -f "$tmp/root/$dst" ]; then err "missing /root/$dst (from $PAYLOAD/$rel)"
  elif ! cmp -s "$src" "$tmp/root/$dst"; then err "/root/$dst differs from $PAYLOAD/$rel"
  fi
  checked=$((checked + 1))
done < <(find "$PAYLOAD" -type f -print0)
[ -f "$tmp/root/install.sh" ] && [ -f "$tmp/root/.profile" ] || err "/root must contain install.sh and .profile"
for n in $(seq 1 13); do
  [ -f "$tmp/root/bandit$n.sh" ] || err "missing /root/bandit$n.sh"
done
[ "$INSTALLER" = install.sh ] || [ ! -e "$tmp/root/$INSTALLER" ] || err "$INSTALLER should have been renamed to install.sh"

# Only the payload folder belongs in the image: no CI files, other labs, or saved sessions.
for f in .github web "bandit current status.txt" basic1.sh level1FM.sh TJInstall.sh dictionaries etc polybandit3.1 bandit solvers; do
  [ ! -e "$tmp/root/$f" ] || err "unexpected file in /root: $f (package with --payload-subdir $PAYLOAD)"
done

case "$FLAVOR" in
  v3)
    grep -q 'levelsetname="bandit"' "$tmp/root/install.sh" 2>/dev/null \
      || err "/root/install.sh is not the bandit installer"
    grep -qx 'wait' "$tmp/root/install.sh" 2>/dev/null \
      || err "/root/install.sh does not wait for the level generators before su -l bandit1"
    ;;
  v31)
    grep -q '^LAB_ID=polybandit$' "$tmp/root/install.sh" 2>/dev/null \
      || err "/root/install.sh is not the PolyBandit 3.1 installer"
    for f in polylinux-common.sh polylinux-colors.sh assets/binary-noise-1024.b64 assets/text-records.txt; do
      [ -f "$tmp/root/$f" ] || err "missing /root/$f"
    done
    ;;
  *) err "unknown flavor $FLAVOR" ;;
esac

if crlf=$(grep -rlI $'\r' "$tmp/root" --include='*.sh' --include=.profile --include=profile --include=nextlevel --include=prevlevel); then
  err "CRLF line endings in: $crlf"
fi

[ "$fail" -eq 0 ] && echo "Image verification passed ($FLAVOR: $checked payload files from $PAYLOAD/ match /root)."
exit "$fail"
