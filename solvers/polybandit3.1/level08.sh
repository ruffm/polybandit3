#!/bin/sh
# PolyBandit 3.1 level 8 reference solver. Runs in the guest as bandit8, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
grep -w millionth data.txt | awk '{print $2}'
