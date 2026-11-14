#!/bin/sh
# PolyBandit 3.1 level 2 reference solver. Runs in the guest as bandit2, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
cat ./-
