#!/bin/sh
# PolyBandit 3.1 level 13 reference solver. Runs in the guest as bandit13, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
# Reverse the hexdump, then peel layers by what file(1) says, until text.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xxd -r data.txt > "$work/layer"
cd "$work"
i=0
while [ "$i" -lt 20 ]; do
    case "$(file -b layer)" in
        *gzip*)  gzip -dc layer > next ;;
        *bzip2*) bzip2 -dc layer > next ;;
        *tar\ archive*)
            name=$(tar -tf layer | head -n 1)
            tar -xf layer
            mv "$name" next ;;
        *text*) awk '{print $NF}' layer; exit 0 ;;
        *) echo "level 13 solver: unexpected layer type: $(file -b layer)" >&2; exit 1 ;;
    esac
    mv next layer
    i=$((i + 1))
done
echo "level 13 solver: too many layers" >&2
exit 1
