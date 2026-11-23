---
name: verify
description: How to launch and drive the quickshell config and the GTK/Nautilus surfaces in this dotfiles repo to verify a change live.
---

## Launch
The shell is already running (`qs -c ~/.config/quickshell`, started by Hyprland autostart) and hot-reloads on file changes. Apply a worktree's version live with `sh .agents/skills/verify/apply-check.sh <worktree>`. It runs `chezmoi --source <worktree> apply ~/.config/quickshell`, waits for the reload, and exits non-zero on any ERROR, TypeError, ReferenceError or "unavailable" line since the last reload, or if IPC is down. "Configuration Loaded" alone is not success: a failed reload keeps the previous scene running. Roll back with `chezmoi apply ~/.config/quickshell` from the main source.

## Font check
`sh .agents/skills/verify/font-check.sh [--source <dir>]` verifies the Inter/Maple Mono font defaults and 3/2 (1.5) scaling. With no arguments it checks the live session: `fc-match` resolves sans to Inter and monospace to Maple Mono; gsettings holds `Inter 11`/`Inter 11`/`Maple Mono 10`; DP-1 is at scale 3/2 — 2560x1440 logical on this 32" 4K panel, and an exact integer division of 3840x2160 so Hyprland keeps it as written — checked within 0.001 (`hyprctl`); `xrdb` shows `Xft.dpi: 144` and `Xcursor.size: 36`; qt6ct's general/fixed fonts match the exact Qt6 `QFont::toString` strings; and the running quickshell process carries `QT_QPA_PLATFORMTHEME=qt6ct` with no `QT_FONT_DPI`/`QT_SCALE_FACTOR`/`QT_QPA_FONTDIR`/`GDK_SCALE`/`GDK_DPI_SCALE` (read from `/proc`, so quickshell must be restarted after changing env.lua). With `--source <dir>` it renders only that chezmoi source tree through `chezmoi --source cat`/`execute-template` and checks the rendered env.lua, monitors, xresources, qt6ct, hyprlock, gtk, hyprtoolkit and Zed targets. Source mode also exercises behavior against isolated state, never live: the rendered `60-inter.conf` is proven with an isolated `fc-match` under a temporary HOME/XDG config and cache (real user font files stay visible, live user aliases and caches are untouched), and the rendered gsettings run script is executed twice against a PATH `gsettings` double in a temp dir that records the calls (idempotence: identical calls both runs; failure path: a double that exits 1 must make the script fail). Because chezmoi cannot override `.chezmoi.os` for `execute-template`, the run template's off-Linux no-op is asserted structurally: its only template actions are the `linux` if/end guard and `gsettings` appears only inside it. It exits non-zero on failure, printing one `FAIL:` line per problem.

## Drive
- Pad: `qs ipc -c ~/.config/quickshell call pad toggleOverview`; see it with `hyprctl clients -j` (title quickshell-pad).
- Layer surfaces (OSD, notification stack): `hyprctl layers -j | jq '[.[].levels[][] | select(.namespace|test("quickshell")) | {h,w}]'`. The OSD's height is 1 when hidden and about 56 when shown.
- Volume toast: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+`. Mic toast with no mic present: `pactl load-module module-null-sink media.class=Audio/Source/Virtual sink_name=testmic`, then `pactl set-default-source testmic`, `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`, and finally `pactl unload-module <id>`.
- Notifications: `notify-send -A yes=Yes ...`, `notify-send -i <png> ...`. History persists in `$XDG_RUNTIME_DIR/quickshell-notifications.json`.
- Search scorer: `node private_dot_config/quickshell/modules/pad/searchScore.test.mjs`.
- Capture with `grim <output.png>`. No input-injection tool is installed (no wtype or ydotool). AT-SPI through `/usr/bin/python3` and `gi.repository.Atspi` can drive many GTK controls; browser upload input may still need a human.

## GTK and Nautilus
- Apply the worktree with `chezmoi --source <worktree> apply`, then run `~/.config/hypr/theme/apply-theme.sh`. Generated outputs are ignored by chezmoi, so `chezmoi --source <worktree> diff` is empty after a successful apply.
- `nautilus -q` quits windows for the next fresh launch. Nautilus 51.1 returns 255 after a successful D-Bus quit, and apply-theme accepts that status deliberately. Other GTK4 apps need a manual restart.
- Inspect with `GTK_DEBUG=interactive nautilus`. Check native clients with `hyprctl clients -j` and class `org.gnome.Nautilus`, `xwayland false`.
- Capture with `grim <output.png>`.
- Portal probe: `gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.FileChooser.OpenFile '' 'Theme probe' '{}'`. The GTK portal service is `xdg-desktop-portal-gtk` and its client is native Wayland. Focus a test window by address, then close it through Hyprland's Lua dispatcher.
- Hyprland 0.56 Lua form: `hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'`; focus a window with `hl.dsp.focus({ window = "address:<address>" })`; close the active window with `hl.dsp.window.close()`.
- LACT is an available non-Nautilus libadwaita comparison (`lact`).

## Teardown
Re-apply the main source (`chezmoi apply ~/.config/quickshell`) if the branch should not stay live.
