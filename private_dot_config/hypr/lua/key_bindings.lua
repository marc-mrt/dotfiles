---------------------
---- KEYBINDINGS ----
---------------------

local browser = "flatpak run app.zen_browser.zen"
local terminal = "ghostty"
local fileManager = "thunar"

local mainMod = "SUPER"

-- Core apps
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Quickshell
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("qs ipc call pad toggleOverview"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("qs ipc call pad toggleWindows"))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("qs ipc call pad toggleWindowsBack"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call pad openClipboard"))

-- Screenshots (grim + slurp): saved to ~/Pictures/Screenshots and copied.
-- Print / SUPER+SHIFT+S = region, SHIFT+Print = whole screen.
local shot = [[sh -c 'd=~/Pictures/Screenshots; mkdir -p "$d"; f="$d/$(date +%F_%H-%M-%S).png"; grim GEOM "$f" && wl-copy < "$f" && notify-send -i "$f" Screenshot "Saved and copied"']]
local region = shot:gsub("GEOM", function() return [[-g "$(slurp)"]] end)
hl.bind("Print",                   hl.dsp.exec_cmd(region))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(region))
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd((shot:gsub("GEOM ", ""))))

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move the window with mainMod + SHIFT + arrows, resize with mainMod + CTRL + arrows
local step = 40
for dir, d in pairs({ left = { -step, 0 }, right = { step, 0 }, up = { 0, -step }, down = { 0, step } }) do
    hl.bind(mainMod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
    hl.bind(mainMod .. " + CTRL + " .. dir,
        hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
end

-- Scratchpad: mainMod + S shows/hides it, mainMod + ALT + S sends the window there
hl.bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Lock screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Volume (pipewire / wireplumber)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),       { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),      { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),    { locked = true })
 
-- Media keys
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

