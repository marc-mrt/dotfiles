#!/bin/sh
# Verifies Inter as the default UI font, Maple Mono as the monospace, and
# 240/137 (~1.75) desktop scaling.
#
#   font-check.sh                live session: fc-match, gsettings, hyprctl,
#                                xrdb, qt6ct.conf, quickshell process env
#   font-check.sh --source <dir>  chezmoi source tree, read-only: renders
#                                targets through `chezmoi --source cat` and
#                                proves fontconfig resolution and the gsettings
#                                run script against isolated state (temp
#                                HOME/XDG dirs and a PATH gsettings double);
#                                never writes live state

fails=0

fail() { echo "FAIL: $1" >&2; fails=$((fails+1)); }
ok() { echo "ok: $1"; }
group_ok() { [ "$fails" -eq "$1" ] && ok "$2"; }

contains() { printf '%s\n' "$1" | grep -q "$2"; }

# Exact Qt6 QFont::toString output for the two qt6ct fonts, generated with
# this machine's Qt6; asserted whole so a malformed suffix cannot pass.
QT_GENERAL='^general="Inter,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"$'
QT_FIXED='^fixed="Maple Mono,10,-1,5,400,0,0,0,1,0,0,0,0,0,0,1,,0,0"$'

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

    # Fontconfig: prove behavior with an isolated fontconfig — temp HOME,
    # XDG config and cache hold only the rendered conf; the real user font
    # files stay visible (Maple Mono is a user font) but no live user aliases
    # are read and no live cache is written.
    fc=$(chezmoi --source "$SRC" cat ~/.config/fontconfig/conf.d/60-inter.conf 2>/dev/null)
    before=$fails
    if [ -n "$fc" ]; then
        fc_tmp=$(mktemp -d "${TMPDIR:-/tmp}/fontcheck.XXXXXX")
        mkdir -p "$fc_tmp/config/fontconfig/conf.d" "$fc_tmp/cache/fontconfig"
        printf '%s\n' "$fc" > "$fc_tmp/config/fontconfig/conf.d/60-inter.conf"
        real_data=$XDG_DATA_HOME
        [ -n "$real_data" ] || real_data=$HOME/.local/share
        fcm() {
            HOME="$fc_tmp" XDG_CONFIG_HOME="$fc_tmp/config" \
                XDG_CACHE_HOME="$fc_tmp/cache" XDG_DATA_HOME="$real_data" \
                fc-match -f '%{family}' "$1" 2>/dev/null
        }
        [ "$(fcm sans)" = "Inter" ] \
            || fail "isolated fc-match sans does not resolve to Inter"
        [ "$(fcm monospace)" = "Maple Mono" ] \
            || fail "isolated fc-match monospace does not resolve to Maple Mono"
        rm -rf "$fc_tmp"
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
    contains "$monitors" 'scale[[:space:]]*=[[:space:]]*240[[:space:]]*/[[:space:]]*137' \
        || fail "monitor scale is not 240/137 (nearest clean 16:9 scale to 1.75)"

    xr=$(chezmoi --source "$SRC" cat ~/.config/hypr/theme/templates/xresources.tpl 2>/dev/null)
    contains "$xr" '^Xft.dpi: 168$' || fail "Xft.dpi is not 168"
    contains "$xr" '^Xcursor.size: 42$' || fail "Xcursor.size is not 42"
    contains "$xr" 'monitor scale 1.75' || fail "Xresources comment does not say scale 1.75"

    qt=$(chezmoi --source "$SRC" cat ~/.config/qt6ct/qt6ct.conf 2>/dev/null)
    contains "$qt" "$QT_GENERAL" || fail "qt6ct general font is not the exact Qt6 Inter 11 string"
    contains "$qt" "$QT_FIXED" || fail "qt6ct fixed font is not the exact Qt6 Maple Mono 10 string"

    lock=$(chezmoi --source "$SRC" cat ~/.config/hypr/hyprlock.conf 2>/dev/null)
    before=$fails
    if [ -z "$lock" ]; then
        fail "hyprlock.conf not rendered"
    else
        contains "$lock" 'Noto Sans' && fail "hyprlock still uses Noto Sans"
        [ -n "$(printf '%s\n' "$lock" | grep 'font_family = Inter')" ] \
            || fail "hyprlock has no Inter font_family line"
        printf '%s\n' "$lock" | grep 'font_family' | grep -qv 'Inter' \
            && fail "hyprlock font_family is not Inter"
    fi
    group_ok "$before" "hyprlock fonts are Inter/Inter Bold"

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
    # chezmoi cannot override .chezmoi.os for execute-template, so the
    # off-Linux no-op is asserted structurally: the template's only actions
    # are the linux if/end guard, and gsettings appears only inside it.
    if [ -f "$SRC/run_onchange_after_fonts.sh.tmpl" ]; then
        tmpl=$(cat "$SRC/run_onchange_after_fonts.sh.tmpl")
        before=$fails
        actions=$(printf '%s\n' "$tmpl" | grep -o '{{[^}]*}}' | sort)
        expected_actions=$(printf '%s\n' '{{ end -}}' '{{ if eq .chezmoi.os "linux" -}}')
        [ "$actions" = "$expected_actions" ] \
            || fail "run template must contain only the linux guard actions"
        outside=$(printf '%s\n' "$tmpl" | awk '
            index($0, "{{ if eq .chezmoi.os \"linux\"") { guard = 1 }
            index($0, "{{ end") { guard = 0 }
            !guard && $0 !~ /^#/ && /gsettings/ { print }
        ')
        [ -z "$outside" ] || fail "run template calls gsettings outside the linux guard"
        script=$(chezmoi --source "$SRC" execute-template < "$SRC/run_onchange_after_fonts.sh.tmpl" 2>/dev/null)
        [ -n "$script" ] || fail "run_onchange_after_fonts.sh.tmpl rendered empty"
        group_ok "$before" "run template guarded to Linux, renders nonempty"
        [ -n "$script" ] && check_fonts_runscript "$script"

        # Idempotence and failure path against isolated state: a PATH
        # gsettings double records the calls, so the real gsettings is
        # never invoked. Run twice and compare; then a double that fails
        # only its first call must make the script fail — an unguarded
        # script would swallow the failure and exit 0 on the later success.
        tmp=$(mktemp -d "${TMPDIR:-/tmp}/fontcheck.XXXXXX")
        mkdir -p "$tmp/bin" "$tmp/bin-fail"
        printf '#!/bin/sh\necho "$@" >> "$GSETTINGS_LOG"\n' > "$tmp/bin/gsettings"
        printf '#!/bin/sh\nif [ -e "$FAIL_ONCE" ]; then exit 0; fi\n: > "$FAIL_ONCE"\nexit 1\n' > "$tmp/bin-fail/gsettings"
        chmod +x "$tmp/bin/gsettings" "$tmp/bin-fail/gsettings"
        printf '%s\n' "$script" > "$tmp/fonts.sh"
        before=$fails
        GSETTINGS_LOG="$tmp/calls" PATH="$tmp/bin:$PATH" sh "$tmp/fonts.sh"
        GSETTINGS_LOG="$tmp/calls2" PATH="$tmp/bin:$PATH" sh "$tmp/fonts.sh"
        [ -s "$tmp/calls" ] || fail "run script did not reach the gsettings double"
        printf '%s\n' \
            'set org.gnome.desktop.interface font-name Inter 11' \
            'set org.gnome.desktop.interface document-font-name Inter 11' \
            'set org.gnome.desktop.interface monospace-font-name Maple Mono 10' \
            > "$tmp/expected"
        cmp -s "$tmp/expected" "$tmp/calls" \
            || fail "run script writes unexpected gsettings values"
        cmp -s "$tmp/calls" "$tmp/calls2" \
            || fail "run script is not idempotent (second run differs)"
        FAIL_ONCE="$tmp/failed-once" PATH="$tmp/bin-fail:$PATH" sh "$tmp/fonts.sh" 2>/dev/null \
            && fail "run script succeeds despite an earlier gsettings failure"
        group_ok "$before" "run script idempotent, fails when gsettings fails"
        rm -rf "$tmp"
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

    before=$fails
    scale=$(hyprctl monitors -j | jq -r '.[] | select(.name=="DP-1") | .scale')
    if [ -n "$scale" ]; then
        printf '%s\n' "$scale" | awk '
            { d = $1 - 240 / 137; if (d < 0) d = -d; exit (d <= 0.001) ? 0 : 1 }
        ' || fail "DP-1 scale is $scale, not 240/137 (within 0.001)"
    else
        fail "DP-1 scale is unset, not 240/137"
    fi
    group_ok "$before" "DP-1 scale 240/137 (~1.75)"

    before=$fails
    xrdb -query | grep -Eqx 'Xft\.dpi:[[:space:]]+168' || fail "xrdb Xft.dpi is not 168"
    xrdb -query | grep -Eqx 'Xcursor\.size:[[:space:]]+42' || fail "xrdb Xcursor.size is not 42"
    group_ok "$before" "xrdb Xft.dpi 168, Xcursor.size 42"

    qt=$(cat "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null)
    before=$fails
    contains "$qt" "$QT_GENERAL" || fail "live qt6ct general font is not the exact Qt6 Inter 11 string"
    contains "$qt" "$QT_FIXED" || fail "live qt6ct fixed font is not the exact Qt6 Maple Mono 10 string"
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
