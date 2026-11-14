#!/bin/sh
# PolyBandit 3.1 level 4 reference solver. Runs in the guest as bandit4, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
# The only hidden regular file under inhere.
find inhere -type f -name '.*' -exec cat {} \;
