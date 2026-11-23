-- Empty output = catch-all: matches whatever port the display enumerates as.
-- highrr picks the highest refresh rate the display advertises.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    -- Checks stay on: exact 1.75 yields fractional logical pixels at 4K, so
    -- Hyprland autocorrects it to its grid's 5/3 (~1.667).
    scale    = 5 / 3,
    vrr      = false,
})
