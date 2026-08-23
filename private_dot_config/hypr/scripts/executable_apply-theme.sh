#!/usr/bin/env bash
# apply-theme.sh — apply the (always-dark) Carbonfox system theme
set -euo pipefail

echo "$(date '+%T') invoked, PID=$$, PPID=$PPID, parent_cmd=$(ps -o comm= -p $PPID)" >> /tmp/apply-theme.log

WALLPAPER="$HOME/.local/share/wallpapers/wallpaper.jpg"

ZEN_PROFILE="$HOME/.var/app/app.zen_browser.zen/.zen/mfmbi5o6.Default (release)"
ZEN_JS="$ZEN_PROFILE/user-theme.js"

# ── nvim remote theme switch ──────────────────────────────
nvim_apply_theme() {
    local colorscheme="$1"
    local background="$2"
    for socket in /run/user/$(id -u)/nvim.*.0; do
        [[ -S "$socket" ]] || continue
        nvim --server "$socket" --remote-send \
            "<Esc>:set background=${background}<CR>:colorscheme ${colorscheme}<CR>" \
            2>/dev/null || true
    done
}

# 1. Render all templates from palette.lua and produce palette.env
~/.config/hypr/theme/generate.lua
source ~/.config/hypr/theme/palette.env

# 2. Wallpaper
hyprctl hyprpaper wallpaper ", $WALLPAPER, cover"

# Sync hyprlock background path
HYPRLOCK_OVERRIDE="$HOME/.config/hypr/hyprlock-wallpaper.conf"
echo "background {" > "$HYPRLOCK_OVERRIDE"
echo "    path = $WALLPAPER" >> "$HYPRLOCK_OVERRIDE"
echo "}" >> "$HYPRLOCK_OVERRIDE"

# 3. Reload hyprland — picks up the freshly rendered colors.conf
hyprctl reload

# 4. Cursor
hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"
xrdb -merge "$HOME/.Xresources"

# 5. GTK
gsettings set org.gnome.desktop.interface color-scheme "$GTK_SCHEME"
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"

# 6. Zen Browser
[[ -f "$ZEN_JS" ]] && cp "$ZEN_JS" "$ZEN_PROFILE/user.js"

# 7. Neovim — update all running instances
nvim_apply_theme "$NVIM_SCHEME" "$NVIM_BG"

notify-send "Theme" "Carbonfox applied" -i preferences-desktop-wallpaper
