#!/usr/bin/env bash

GENERATE="$HOME/.config/hypr/scripts/generate-theme.sh"
DAY_WALL="$HOME/.local/share/wallpapers/day.jpg"
NIGHT_WALL="$HOME/.local/share/wallpapers/night.jpg"
ZEN_PROFILE="$HOME/.var/app/app.zen_browser.zen/.zen/mfmbi5o6.Default (release)"
ZED_SETTINGS="$HOME/.var/app/dev.zed.Zed/config/zed/settings.json"

HOUR=$(date +%H)

if [[ "$HOUR" -ge 8 && "$HOUR" -lt 21 ]]; then
    MODE="day"
    WALLPAPER="$DAY_WALL"
    MATUGEN_TYPE="light"
    GTK_THEME="catppuccin-latte-standard-mauve-light"
    GTK_SCHEME="prefer-light"
    ZED_THEME="Catppuccin Latte"
    GHOSTTY_COLORS="$HOME/.config/ghostty/colors-light"
    ZEN_JS="$HOME/.zen/user-day.js"
else
    MODE="night"
    WALLPAPER="$NIGHT_WALL"
    MATUGEN_TYPE="dark"
    GTK_THEME="catppuccin-mocha-standard-mauve-dark"
    GTK_SCHEME="prefer-dark"
    ZED_THEME="Catppuccin Mocha"
    GHOSTTY_COLORS="$HOME/.config/ghostty/colors-dark"
    ZEN_JS="$HOME/.zen/user-night.js"
fi

# Skip if already in this mode
STATE_FILE="/tmp/hypr-theme-mode"
[[ -f "$STATE_FILE" ]] && [[ "$(cat $STATE_FILE)" == "$MODE" ]] && exit 0
echo "$MODE" > "$STATE_FILE"

# 1. Wallpaper + matugen
bash "$GENERATE" "$WALLPAPER" "$MATUGEN_TYPE"

# 2. Ghostty — swap symlink
ln -sf "$GHOSTTY_COLORS" "$HOME/.config/ghostty/colors-active"

# 3. GTK
gsettings set org.gnome.desktop.interface color-scheme "$GTK_SCHEME"
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"

# 4. Zed — patch theme in settings.json
if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq --arg t "$ZED_THEME" '.theme = $t' "$ZED_SETTINGS" > "$tmp" && mv "$tmp" "$ZED_SETTINGS"
fi

# 5. Zen Browser
[[ -n "$ZEN_PROFILE" ]] && cp "$ZEN_JS" "$ZEN_PROFILE/user.js"

notify-send "Theme" "Switched to $MODE mode" -i preferences-desktop-wallpaper
