#!/bin/sh
# PolyBandit 3.1 level 11 reference solver. Runs in the guest as bandit11, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
base64 -d data.txt | awk '{print $NF}'
