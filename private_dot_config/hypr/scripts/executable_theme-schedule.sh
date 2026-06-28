#!/usr/bin/env bash

GENERATE="$HOME/.config/hypr/scripts/generate-theme.sh"
DAY_WALL="$HOME/.local/share/wallpapers/day.jpg"
NIGHT_WALL="$HOME/.local/share/wallpapers/night.jpg"
ZEN_PROFILE="$HOME/.var/app/app.zen_browser.zen/.zen/mfmbi5o6.Default (release)"

# ── nvim remote theme switch ──────────────────────────────
nvim_apply_theme() {
    local colorscheme="$1"
    local background="$2"
    # nvim 0.10+ auto-creates socket at XDG_RUNTIME_DIR/nvim.PID.0
    for socket in /run/user/$(id -u)/nvim.*.0; do
        [[ -S "$socket" ]] || continue
        nvim --server "$socket" --remote-send \
            "<Esc>:set background=${background}<CR>:colorscheme ${colorscheme}<CR>" \
            2>/dev/null || true
    done
}

HOUR=$(date +%H)

if [[ "$HOUR" -ge 8 && "$HOUR" -lt 21 ]]; then
    MODE="day"
    WALLPAPER="$DAY_WALL"
    MATUGEN_TYPE="light"
    GTK_THEME="catppuccin-latte-standard-mauve-light"
    GTK_SCHEME="prefer-light"
    GHOSTTY_COLORS="$HOME/.config/ghostty/colors-light"
    ZEN_JS="$ZEN_PROFILE/user-day.js"
    NVIM_SCHEME="catppuccin-latte"
    NVIM_BG="light"
else
    MODE="night"
    WALLPAPER="$NIGHT_WALL"
    MATUGEN_TYPE="dark"
    GTK_THEME="catppuccin-mocha-standard-mauve-dark"
    GTK_SCHEME="prefer-dark"
    GHOSTTY_COLORS="$HOME/.config/ghostty/colors-dark"
    ZEN_JS="$ZEN_PROFILE/user-night.js"
    NVIM_SCHEME="catppuccin-mocha"
    NVIM_BG="dark"
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

# 4. Zen Browser
[[ -n "$ZEN_PROFILE" ]] && cp "$ZEN_JS" "$ZEN_PROFILE/user.js"

# 5. Neovim — update all running instances
nvim_apply_theme "$NVIM_SCHEME" "$NVIM_BG"

notify-send "Theme" "Switched to $MODE mode" -i preferences-desktop-wallpaper
