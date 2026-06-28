#!/usr/bin/env bash
# generate-theme.sh — run on wallpaper change
# Usage: generate-theme.sh /path/to/wallpaper.jpg

set -euo pipefail

WALLPAPER="${1:?Usage: generate-theme.sh <wallpaper>}"
DUNST_BASE="$HOME/.config/dunst/dunstrc.base"
DUNST_OUT="$HOME/.config/dunst/dunstrc"

# 1. Set wallpaper via hyprctl
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ",$WALLPAPER"

# Sync hyprlock background path only
HYPRLOCK_OVERRIDE="$HOME/.config/hypr/hyprlock-wallpaper.conf"
echo "background {" > "$HYPRLOCK_OVERRIDE"
echo "    path = $WALLPAPER" >> "$HYPRLOCK_OVERRIDE"
echo "}" >> "$HYPRLOCK_OVERRIDE"

# 2. Run matugen — fills all templates
MATUGEN_MODE="${2:-dark}"   # default dark
SOURCE_COLOR=$(magick "$WALLPAPER" -resize 1x1 txt:- | grep -oP '#[0-9A-Fa-f]{6}' | head -1)
matugen color hex "$SOURCE_COLOR" --mode "$MATUGEN_MODE" --type scheme-tonal-spot

# 3. Build dunstrc = base + generated colors (no #include support)
cat "$DUNST_BASE" "$HOME/.config/dunst/dunstrc-colors" > "$DUNST_OUT"

# 4. Reload dunst
pkill dunst && dunst &

# 5. Reload waybar
pkill -SIGUSR2 waybar 2>/dev/null || true

# 6. Reload hyprland config (picks up new colors.lua)
hyprctl reload

echo "Theme applied from: $WALLPAPER"
