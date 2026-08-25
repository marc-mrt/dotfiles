hl.config({
    animations = { enabled = true },
})

-- Curves (formerly beziers)
hl.curve("wind",   { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn",  { type = "bezier", points = { { 0.1,  1.1 }, { 0.1, 1.1  } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0,   1    } } })
hl.curve("liner",  { type = "bezier", points = { { 1,    1   }, { 1,   1    } } })

-- Animations
hl.animation({ leaf = "windows",     enabled = true, speed = 6,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6,  bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner",  style = "once" })
hl.animation({ leaf = "fade",        enabled = true, speed = 10, bezier = "default" })
-- fadeDim (the dim_inactive color overlay) interpolates in visible discrete
-- steps in this Hyprland version, independent of blur/opacity/vfr/render
-- settings -- confirmed by isolating it from inactive_opacity, which fades
-- smoothly on its own. Making it instant removes the choppy ramp; the
-- window still darkens the moment focus changes while opacity fades
-- smoothly on top.
hl.animation({ leaf = "fadeDim",     enabled = false })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "wind" })

-- Quickshell's pad + notification stack are wlr-layer-shell surfaces
-- (PanelWindow), so their show/hide animates via this "layers" category,
-- not "windows" — without an explicit override they were falling back to
-- the slower default fade above. speed = 2 -> 200ms.
hl.animation({ leaf = "layersIn",  enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "default" })
