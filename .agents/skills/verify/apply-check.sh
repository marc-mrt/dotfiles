#!/bin/sh
# Apply the branch to the live quickshell config, wait for the reload, and
# fail if anything since the last "Reloading configuration" is an error.
WT=${1:?worktree}
chezmoi --source "$WT" apply ~/.config/quickshell </dev/null || exit 1
sleep 4
out=$(qs log -c ~/.config/quickshell | awk '/Reloading configuration/{buf=""} {buf=buf"\n"$0} END{print buf}')
echo "$out" | grep -E 'ERROR|TypeError|ReferenceError|unavailable' && exit 2
qs ipc -c ~/.config/quickshell show >/dev/null || exit 3
echo ok
