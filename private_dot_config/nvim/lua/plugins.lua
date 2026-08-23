-- Register the mise treesitter predicate before any plugin setup
require("vim.treesitter.query").add_predicate("is-mise?", function(_, _, bufnr, _)
  local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
  local filename = vim.fn.fnamemodify(filepath, ":t")
  return string.match(filename, ".*mise.*%.toml$") ~= nil
end, { force = true, all = false })

vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
  local name, kind = ev.data.spec.name, ev.data.kind
  if name == 'nvim-treesitter' and kind == 'update' then
    if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
    vim.cmd('TSUpdate')
  end
end })

-- Plugins
vim.pack.add({
  'https://github.com/edeneast/nightfox.nvim',
  'https://github.com/nvim-mini/mini.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/nvim-treesitter/nvim-treesitter',
})

require('mini.basics').setup()
require('mini.surround').setup()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.notify').setup()
require('mini.icons').setup()
require('mini.starter').setup()

-- Treesitter
require('nvim-treesitter.config').setup({
  ensure_installed = { 'toml', 'lua', 'python', 'go', 'typescript', 'json', 'javascript', 'rust' },
  auto_install = true,
  highlight = { enable = true },
})

