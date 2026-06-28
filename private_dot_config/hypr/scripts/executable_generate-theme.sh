#!/usr/bin/env bash
# generate-theme.sh — run on wallpaper change
# Usage: generate-theme.sh /path/to/wallpaper.jpg

set -euo pipefail

WALLPAPER="${1:?Usage: generate-theme.sh <wallpaper>}"
DUNST_BASE="$HOME/.config/dunst/dunstrc.base"
DUNST_OUT="$HOME/.config/dunst/dunstrc"

# 1. Set wallpaper via hyprctl
hyprctl hyprpaper wallpaper ",$WALLPAPER"

# 2. Run matugen — fills all templates
MATUGEN_TYPE="${2:-dark}"   # default dark
matugen image "$WALLPAPER" --type "$MATUGEN_TYPE"

# 3. Build dunstrc = base + generated colors (no #include support)
cat "$DUNST_BASE" "$HOME/.config/dunst/dunstrc-colors" > "$DUNST_OUT"

# 4. Reload dunst
pkill dunst && dunst &

# 5. Reload waybar
pkill -SIGUSR2 waybar || killall waybar && waybar &

# 6. Reload hyprland config (picks up new colors.lua)
hyprctl reload

echo "Theme applied from: $WALLPAPER"
