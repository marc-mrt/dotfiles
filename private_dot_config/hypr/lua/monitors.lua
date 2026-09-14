-- Empty output = catch-all: matches whatever port the display enumerates as.
-- highrr picks the highest refresh rate the display advertises.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1.25,
    vrr      = false,
})
