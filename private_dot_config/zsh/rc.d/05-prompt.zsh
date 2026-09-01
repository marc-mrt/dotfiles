#!/bin/zsh

##
# Prompt theme
#

# Starship.
# Guarded so a machine that doesn't have it yet still opens a usable shell.
command -v starship >/dev/null &&
    eval "$(starship init zsh)"
