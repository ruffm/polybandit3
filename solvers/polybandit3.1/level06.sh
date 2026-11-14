#!/bin/sh
# PolyBandit 3.1 level 6 reference solver. Runs in the guest as bandit6, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
# Regular file, exactly 205 bytes, not executable, human-readable; first line.
find inhere -type f -size 205c | while IFS= read -r f; do
    [ -x "$f" ] && continue
    case "$(file -b "$f")" in *text*) head -n 1 "$f" ;; esac
done
