vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            workspace = {
                library = { "/usr/share/hypr/stubs" },
            },
        },
    },
})

vim.lsp.enable({
  'lua_ls',
  'pyright',
  'gopls',
  'ts_ls',
  'jsonls',
  'rust_analyzer',
})
