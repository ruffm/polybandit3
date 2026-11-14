#!/bin/sh
# PolyBandit 3.1 level 12 reference solver. Runs in the guest as bandit12, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
tr 'A-Za-z' 'N-ZA-Mn-za-m' < data.txt | awk '{print $NF}'
