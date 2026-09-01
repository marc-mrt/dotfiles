-- Order matters:
--   options  sets <leader> before any mapping is defined
--   plugins  loads mini.* and treesitter
--   keymaps  binds the pickers/explorer that plugins.lua just created
--   theme    applies colours last, so nothing overwrites the highlights
--   lsp      servers and diagnostics
require("options")
require("plugins")
require("keymaps")
require("theme")
require("lsp")
