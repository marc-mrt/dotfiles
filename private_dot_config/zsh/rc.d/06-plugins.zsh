##
# Plugins
#

local -a plugins=(
    marlonrichert/zsh-autocomplete
    marlonrichert/zsh-edit
    marlonrichert/zsh-hist
    marlonrichert/zcolors
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
)

znap clone $plugins

local p=
for p in $plugins; do
  znap source $p
done

znap eval zcolors zcolors   # Extra init code needed for zcolors.
