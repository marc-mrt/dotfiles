#!/bin/zsh

##
# Environment variables
#

# -U ensures each entry in these is unique (that is, discards duplicates).
export -U PATH path FPATH fpath MANPATH manpath
export -UT INFOPATH infopath

# $PATH and $path (and also $FPATH and $fpath, etc.) are "tied" to each other.
# Modifying one will also modify the other.
# Note that each value in an array is expanded separately. Thus, we can use ~
# for $HOME in each $path entry.
path=(
    ~/.local/bin
    ~/.bun/bin
    $path
)

# In order to be able to `autoload` a function for use on the command line, it
# either needs to be in your $fpath or you need to autoload by absolute path.
# (Note: Zsh's completions system will automatically autoload completion
# functions inside dirs that are in your $fpath. So, no need to explicitly
# autoload those.
fpath=(
    $ZDOTDIR/functions
    ~/.local/share/zsh/site-functions
    $fpath
)

# Mise
eval "$(mise activate zsh)"

# gpg key
export GPG_TTY=$TTY

# editor
export PAGER=less
export EDITOR=nvim
export VISUAL="flatpak run dev.zed.Zed -n"
