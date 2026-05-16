return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    vim.treesitter.query.add_predicate("is-mise?", function(_, _, bufnr, _)
      local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
      local filename = vim.fn.fnamemodify(filepath, ":t")
      return string.match(filename, ".*mise.*%.toml$") ~= nil
    end, { force = true, all = false })

    require("nvim-treesitter").setup({
      ensure_install = { "toml", "lua", "python", "go", "typescript", "json", "javascript", "rust" },
      auto_install = true,
    })
  end,
}
