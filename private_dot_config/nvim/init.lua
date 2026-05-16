require("config.lazy")

vim.cmd('colorscheme tokyonight')

---@type nvim_tree.config
local config = {
  sort = {
    sorter = "case_sensitive",
  },
  view = {
    width = 30,
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = true,
  },
}

require("nvim-tree").setup(config)
