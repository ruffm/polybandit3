#!/bin/sh
# PolyBandit 3.1 level 7 reference solver. Runs in the guest as bandit7, in $HOME;
# prints the answer. Uses the tool the level teaches. Never packaged into the image.
set -eu
cd "$HOME"
# Anywhere on the system: owner bandit7, group bandit6, exactly 21 bytes.
find / -type f -user bandit7 -group bandit6 -size 21c 2>/dev/null | while IFS= read -r f; do cat "$f"; done
