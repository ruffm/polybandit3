#!/bin/sh
# PolyBandit 3.1 level 5 reference solver. Runs in the guest as bandit5, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
# The only candidate that file(1) classifies as text.
for f in inhere/*; do
    case "$(file -b "./$f")" in *text*) cat "./$f" ;; esac
done
