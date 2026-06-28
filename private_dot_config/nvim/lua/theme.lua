-- Static base: Catppuccin Mocha
-- matugen writes ~/.config/nvim/lua/palette.lua
-- and this file overrides highlight groups from it

vim.cmd.colorscheme("catppuccin-mocha")

-- Override with matugen palette if available
local ok, P = pcall(require, "palette")
if ok then
    local hl = vim.api.nvim_set_hl
    hl(0, "Normal",       { bg = P.surface,    fg = P.on_surface })
    hl(0, "NormalFloat",  { bg = P.surface,    fg = P.on_surface })
    hl(0, "FloatBorder",  { fg = P.primary })
    hl(0, "CursorLine",   { bg = P.surface })
    hl(0, "Visual",       { bg = P.secondary .. "55" })
    hl(0, "StatusLine",   { bg = P.surface,    fg = P.on_surface })
end
