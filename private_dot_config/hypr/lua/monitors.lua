-- Empty output = catch-all: matches whatever port the display enumerates as.
-- highrr picks the highest refresh rate the display advertises.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    -- 3/2 is the 32" 4K sweet spot: 2560x1440 logical (92.9 logical PPI, the
    -- same density as a 32" 1440p panel). Divides 3840x2160 into exact
    -- integers, so Hyprland keeps it as written instead of autocorrecting.
    scale    = 3 / 2,
    vrr      = false,
})
