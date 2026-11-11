---
name: verify
description: How to launch and drive the quickshell config in this dotfiles repo to verify a change live.
---

## Launch
The shell is already running (`qs -c ~/.config/quickshell`, started by Hyprland autostart) and hot-reloads on file changes. Apply a worktree's version live with `sh .agents/skills/verify/apply-check.sh <worktree>`. It runs `chezmoi --source <worktree> apply ~/.config/quickshell`, waits for the reload, and exits non-zero on any ERROR, TypeError, ReferenceError or "unavailable" line since the last reload, or if IPC is down. "Configuration Loaded" alone is not success: a failed reload keeps the previous scene running. Roll back with `chezmoi apply ~/.config/quickshell` from the main source.

## Drive
- Pad: `qs ipc -c ~/.config/quickshell call pad toggleOverview`; see it with `hyprctl clients -j` (title quickshell-pad).
- Layer surfaces (OSD, notification stack): `hyprctl layers -j | jq '[.[].levels[][] | select(.namespace|test("quickshell")) | {h,w}]'`. The OSD's height is 1 when hidden and about 56 when shown.
- Volume toast: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+`. Mic toast with no mic present: `pactl load-module module-null-sink media.class=Audio/Source/Virtual sink_name=testmic`, then `pactl set-default-source testmic`, `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`, and finally `pactl unload-module <id>`.
- Notifications: `notify-send -A yes=Yes ...`, `notify-send -i <png> ...`. History persists in `$XDG_RUNTIME_DIR/quickshell-notifications.json`.
- Search scorer: `node private_dot_config/quickshell/modules/pad/searchScore.test.mjs`.
- No screenshot or input-injection tool is installed (no grim, ydotool or wtype), so clicks, typing and visuals need a human.

## Teardown
Re-apply the main source (`chezmoi apply ~/.config/quickshell`) if the branch should not stay live.
