#!/bin/sh
# PolyBandit 3.1 level 10 reference solver. Runs in the guest as bandit10, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
# Printable strings preceded by "====== "; the answer is the 20-character one.
strings data.txt | sed -n 's/^====== //p' | awk 'length($0) == 20'
