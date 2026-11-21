##
# Plugins
#

local -a plugins=(
    marlonrichert/zsh-autocomplete
    marlonrichert/zsh-edit
    marlonrichert/zsh-hist
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
)

# zcolors is not a sourceable plugin: it is a script that prints a theme.
znap clone $plugins marlonrichert/zcolors

local p=
for p in $plugins; do
  znap source $p
done

# `zsh -f`: do not rely on the script's #!/bin/zsh shebang (zsh lives elsewhere
# on some Linux systems).
znap eval marlonrichert/zcolors 'zsh -f ./zcolors'
