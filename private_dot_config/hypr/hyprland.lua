require("lua/monitors")
require("lua/env")
require("lua/autostart")
require("lua/options")
require("lua/animations")
require("lua/key_bindings")
require("lua/window_rules")

-- Per-machine overrides, owned by the user rather than by this repo: mouse
-- sensitivity and monitor brightness as last set from the Quickshell pad.
-- Written by ~/.config/quickshell/services/HyprOverrides.qml and ignored by
-- chezmoi, so it stays on the one machine instead of syncing everywhere.
-- Required last so it wins over lua/options.lua; pcall because it only
-- exists once something has actually been changed.
pcall(require, "lua/user-overrides")
