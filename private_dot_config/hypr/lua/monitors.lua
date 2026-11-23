-- Empty output = catch-all: matches whatever port the display enumerates as.
-- highrr picks the highest refresh rate the display advertises.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    -- 240/137 ~= 1.752: nearest scale to 1.75 that keeps 3840x2160 at integer
    -- logical pixels (2192x1233); exact 1.75 gets autocorrected by Hyprland.
    scale    = 240 / 137,
    vrr      = false,
})
