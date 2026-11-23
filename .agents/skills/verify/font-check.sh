#!/bin/sh
# Verifies Inter as the default UI font, Maple Mono as the monospace, and
# 1.75 desktop scaling.
#
#   font-check.sh                live session: fc-match, gsettings, hyprctl,
#                                xrdb, qt6ct.conf, quickshell process env
#   font-check.sh --source <dir>  chezmoi source tree, read-only: renders
#                                targets through `chezmoi --source cat`; never
#                                executes run scripts or touches live state

fails=0

fail() { echo "FAIL: $1" >&2; fails=$((fails+1)); }
ok() { echo "ok: $1"; }
group_ok() { [ "$fails" -eq "$1" ] && ok "$2"; }

contains() { printf '%s\n' "$1" | grep -q "$2"; }

check_fonts_runscript() { # $1 = rendered run_onchange_after_fonts.sh
    contains "$1" "gsettings set org.gnome.desktop.interface font-name 'Inter 11'" \
        || fail "gsettings font-name is not Inter 11"
    contains "$1" "gsettings set org.gnome.desktop.interface document-font-name 'Inter 11'" \
        || fail "gsettings document-font-name is not Inter 11"
    contains "$1" "gsettings set org.gnome.desktop.interface monospace-font-name 'Maple Mono 10'" \
        || fail "gsettings monospace-font-name is not Maple Mono 10"
}

source_mode() {
    SRC=$1
    [ -d "$SRC" ] || { echo "no such source dir: $SRC" >&2; exit 2; }

    # Fontconfig: generic sans-serif -> Inter, generic monospace -> Maple Mono
    fc=$(chezmoi --source "$SRC" cat ~/.config/fontconfig/conf.d/60-inter.conf 2>/dev/null)
    before=$fails
    if [ -n "$fc" ]; then
        printf '%s\n' "$fc" | sed -n '/<family>sans-serif<\/family>/,/<\/alias>/p' \
            | grep -q '<family>Inter</family>' \
            || fail "fontconfig sans-serif does not prefer Inter"
        printf '%s\n' "$fc" | sed -n '/<family>monospace<\/family>/,/<\/alias>/p' \
            | grep -q '<family>Maple Mono</family>' \
            || fail "fontconfig monospace does not prefer Maple Mono"
    else
        fail "no fontconfig 60-inter.conf in source"
    fi
    group_ok "$before" "fontconfig sans-serif=Inter monospace=Maple Mono"

    env=$(chezmoi --source "$SRC" cat ~/.config/hypr/lua/env.lua 2>/dev/null)
    before=$fails
    if [ -n "$env" ]; then
        contains "$env" 'hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")' \
            || fail "env.lua does not set QT_QPA_PLATFORMTHEME=qt6ct"
        printf '%s\n' "$env" \
            | grep -Eq 'QT_FONT_DPI|QT_SCALE_FACTOR|QT_QPA_FONTDIR|GDK_SCALE|GDK_DPI_SCALE' \
            && fail "env.lua sets a forbidden Qt/GDK scaling variable"
    else
        fail "env.lua not managed by source"
    fi
    group_ok "$before" "env.lua qt6ct theme, no forbidden scaling vars"

    monitors=$(chezmoi --source "$SRC" cat ~/.config/hypr/lua/monitors.lua 2>/dev/null)
    contains "$monitors" 'scale[[:space:]]*=[[:space:]]*1\.75' \
        || fail "monitor scale is not 1.75"

    xr=$(chezmoi --source "$SRC" cat ~/.config/hypr/theme/templates/xresources.tpl 2>/dev/null)
    contains "$xr" '^Xft.dpi: 168$' || fail "Xft.dpi is not 168"
    contains "$xr" '^Xcursor.size: 42$' || fail "Xcursor.size is not 42"

    qt=$(chezmoi --source "$SRC" cat ~/.config/qt6ct/qt6ct.conf 2>/dev/null)
    contains "$qt" '^general="Inter,11,' || fail "qt6ct general font is not Inter 11"
    contains "$qt" '^fixed="Maple Mono,10,' || fail "qt6ct fixed font is not Maple Mono 10"

    lock=$(chezmoi --source "$SRC" cat ~/.config/hypr/hyprlock.conf 2>/dev/null)
    contains "$lock" 'Noto Sans' && fail "hyprlock still uses Noto Sans"
    printf '%s\n' "$lock" | grep 'font_family' | grep -qv 'Inter' \
        && fail "hyprlock font_family is not Inter"

    gtk=$(chezmoi --source "$SRC" cat ~/.config/hypr/theme/templates/gtk-settings.ini.tpl 2>/dev/null)
    contains "$gtk" '^gtk-font-name=Inter 11$' || fail "gtk-font-name is not Inter 11"

    tk=$(chezmoi --source "$SRC" cat ~/.config/hypr/theme/templates/hyprtoolkit.conf.tpl 2>/dev/null)
    contains "$tk" '^font_family[[:space:]]*=[[:space:]]*Inter$' \
        || fail "hyprtoolkit font_family is not Inter"
    contains "$tk" '^font_family_monospace[[:space:]]*=[[:space:]]*Maple Mono$' \
        || fail "hyprtoolkit font_family_monospace is not Maple Mono"

    zed=$(chezmoi --source "$SRC" cat ~/.var/app/dev.zed.Zed/config/zed/settings.json 2>/dev/null)
    contains "$zed" '"ui_font_family": "Inter"' || fail "Zed ui_font_family is not Inter"
    contains "$zed" '"buffer_font_family": "Maple Mono"' \
        || fail "Zed buffer_font_family is not Maple Mono"

    # Run scripts are not `cat`-able; render the template read-only instead.
    if [ -f "$SRC/run_onchange_after_fonts.sh.tmpl" ]; then
        script=$(chezmoi --source "$SRC" execute-template < "$SRC/run_onchange_after_fonts.sh.tmpl" 2>/dev/null)
        [ -n "$script" ] && check_fonts_runscript "$script"
    else
        fail "no run_onchange_after_fonts.sh.tmpl in source"
    fi

    ig=$(cat "$SRC/.chezmoiignore" 2>/dev/null)
    contains "$ig" '^\.config/fontconfig$' \
        || fail ".chezmoiignore non-Linux block lacks .config/fontconfig"
    contains "$ig" '^\.config/qt6ct$' \
        || fail ".chezmoiignore non-Linux block lacks .config/qt6ct"
}

live_mode() {
    before=$fails
    [ "$(fc-match -f '%{family}' sans)" = "Inter" ] \
        || fail "fc-match sans is $(fc-match -f '%{family}' sans), not Inter"
    [ "$(fc-match -f '%{family}' monospace)" = "Maple Mono" ] \
        || fail "fc-match monospace is $(fc-match -f '%{family}' monospace), not Maple Mono"
    group_ok "$before" "fc-match sans=Inter monospace=Maple Mono"

    before=$fails
    [ "$(gsettings get org.gnome.desktop.interface font-name)" = "'Inter 11'" ] \
        || fail "gsettings font-name is $(gsettings get org.gnome.desktop.interface font-name)"
    [ "$(gsettings get org.gnome.desktop.interface document-font-name)" = "'Inter 11'" ] \
        || fail "gsettings document-font-name is $(gsettings get org.gnome.desktop.interface document-font-name)"
    [ "$(gsettings get org.gnome.desktop.interface monospace-font-name)" = "'Maple Mono 10'" ] \
        || fail "gsettings monospace-font-name is $(gsettings get org.gnome.desktop.interface monospace-font-name)"
    group_ok "$before" "gsettings fonts Inter 11 / Inter 11 / Maple Mono 10"

    scale=$(hyprctl monitors -j | jq -r '.[] | select(.name=="DP-1") | .scale')
    [ "$scale" = "1.75" ] || fail "DP-1 scale is ${scale:-unset}, not 1.75"
    ok "DP-1 scale 1.75"

    xrdb -query | grep -qx 'Xft.dpi: 168' || fail "xrdb Xft.dpi is not 168"
    ok "Xft.dpi 168"

    qt=$(cat "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null)
    before=$fails
    contains "$qt" '^general="Inter,11,' || fail "live qt6ct general font is not Inter 11"
    contains "$qt" '^fixed="Maple Mono,10,' || fail "live qt6ct fixed font is not Maple Mono 10"
    group_ok "$before" "qt6ct general Inter 11, fixed Maple Mono 10"

    # The quickshell process, not this shell, must carry the Qt theme env.
    before=$fails
    pids=$(pgrep -x qs)
    [ -n "$pids" ] || fail "no quickshell (qs) process running"
    for pid in $pids; do
        env=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null)
        contains "$env" '^QT_QPA_PLATFORMTHEME=qt6ct$' \
            || fail "quickshell pid $pid lacks QT_QPA_PLATFORMTHEME=qt6ct"
        printf '%s\n' "$env" \
            | grep -Eq '^(QT_FONT_DPI|QT_SCALE_FACTOR|QT_QPA_FONTDIR|GDK_SCALE|GDK_DPI_SCALE)=' \
            && fail "quickshell pid $pid carries a forbidden Qt/GDK scaling variable"
    done
    group_ok "$before" "quickshell env QT_QPA_PLATFORMTHEME=qt6ct, no forbidden scaling vars"
}

if [ "$1" = "--source" ]; then
    [ $# -eq 2 ] || { echo "usage: $0 [--source <dir>]" >&2; exit 2; }
    source_mode "$2"
else
    live_mode
fi

[ "$fails" -eq 0 ] && echo "all font checks passed"
exit "$fails"
