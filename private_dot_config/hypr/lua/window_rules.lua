--------------------
---- WINDOW RULES --
--------------------
 
-- Suppress accidental maximize requests
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})
 
-- XWayland drag fix
hl.window_rule({
    name     = "fix-xwayland-drags",
    match    = { class = "^$", title = "^$", xwayland = true, float = true,
                 fullscreen = false, pin = false },
    no_focus = true,
})
 
-- Ghostty: force full opacity (overrides the global inactive_opacity)
-- opacity string: "active override inactive override fullscreen override"
hl.window_rule({
    name    = "ghostty-opacity",
    match   = { class = "^com.mitchellh.ghostty$" },
    opacity = "1.0 override 0.9 override",
})
 
-- Zen browser picture-in-picture: floating, pinned, fixed size + position
hl.window_rule({
    name  = "zen-pip",
    match = { class = "^zen.*", title = "^Picture-in-Picture$" },
    float = true,
    pin   = true,
    size  = "480 270",
    move  = "80% 72%",
})
 
-- Common floating dialogs
hl.window_rule({
    name   = "float-dialogs",
    match  = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|thunar)$" },
    float  = true,
    center = true,
})
 

