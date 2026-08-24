vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
  end,
})

require('nightfox').setup({
  options = {
    transparent_background = true,
  },
})

-- vim.o.background = "dark"
vim.cmd.colorscheme("carbonfox")

-- A script to generate the color palette is auto-started via hypr
-- which this then inherits
local ok, P = pcall(require, "palette")
if ok then
    local hl = vim.api.nvim_set_hl
    hl(0, "Normal",      { fg = P.on_surface })
    hl(0, "NormalFloat", { bg = P.surface,    fg = P.on_surface })
    hl(0, "FloatBorder", { fg = P.primary })
    hl(0, "CursorLine",  { bg = P.surface })
    hl(0, "Visual",      { bg = P.secondary,  blend = 30 })  -- blend = 0-100, replaces alpha
    hl(0, "StatusLine",  { bg = P.surface,    fg = P.on_surface })
end
