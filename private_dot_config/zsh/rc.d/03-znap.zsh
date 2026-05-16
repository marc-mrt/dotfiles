#!/bin/zsh

##
# Plugin manager
#

local znap=$ZDOTDIR/znap/zsh-snap/znap.zsh

# Auto-install Znap if it's not there yet.
if ! [[ -r $znap ]]; then
  git -C $ZDOTDIR/znap clone --depth 1 -- https://github.com/marlonrichert/zsh-snap.git
fi

. $znap
