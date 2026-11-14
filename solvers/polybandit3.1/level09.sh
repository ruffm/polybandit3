#!/bin/sh
# PolyBandit 3.1 level 9 reference solver. Runs in the guest as bandit9, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
sort data.txt | uniq -u
