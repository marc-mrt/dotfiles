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
 
-- Quickshell pad (SUPER+SPACE / SUPER+Tab). Deliberately a real toplevel
-- rather than a layer surface, so Hyprland focuses it on map and the
-- window behind it gets the inactive treatment (border, dim_inactive,
-- inactive_opacity) instead of still looking like the focused one -- a
-- layer surface can never do that, it keeps the last-window pointer aimed
-- at whatever was focused before.
--
-- It maps at full monitor size and never resizes (a floating toplevel
-- can't resize itself after map -- Hyprland keeps the size it configured
-- and ignores later requests -- so the card inside does the growing).
-- Everything visible is drawn by the shell itself onto a transparent
-- surface, hence no border, no rounding and no blur: the compositor
-- decorating a screen-sized transparent window would just put a frame
-- around the whole monitor and blur the entire desktop.
hl.window_rule({
    name        = "quickshell-pad",
    match       = { class = "^org\\.quickshell$" },
    float       = true,
    pin         = true,
    move        = "0 0",
    border_size = 0,   -- not no_border, which this parser rejects
    rounding    = 0,
    no_blur     = true,
    no_anim     = true,
})

-- Common floating dialogs
hl.window_rule({
    name   = "float-dialogs",
    match  = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|thunar)$" },
    float  = true,
    center = true,
})
 

