#!/bin/zsh

##
# Named directories

hash -d tmp=$TMPDIR zsh=$ZDOTDIR
# `hash -d <name>=<path>` makes ~<name> a shortcut for <path>.
