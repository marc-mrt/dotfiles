---------------------
---- KEYBINDINGS ----
---------------------

local browser = "flatpak run app.zen_browser.zen"
local terminal = "ghostty"
local fileManager = "thunar"

local mainMod = "SUPER"

-- Maps capslock (the intended mainMod) to super
hl.config({
  input = {
    kb_options = "caps:super"
  }
})

-- Core apps
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- App launcher
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("rofi -show drun -theme ~/.config/rofi/launcher.rasi"))

-- Window switcher
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("rofi -show window -theme ~/.config/rofi/window.rasi"))

-- Run prompt
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("rofi -show run -theme ~/.config/rofi/launcher.rasi"))

-- Walpaper switcher
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(
    "rofi -show filebrowser -theme ~/.config/rofi/launcher.rasi" ..
    " | xargs -I{} ~/.config/hyde-personal/scripts/generate-theme.sh {}"
))

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

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

-- Reload Waybar
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("killall -SIGUSR2 waybar"))
 
-- Reload wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprctl hyprpaper reload"))
 
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

