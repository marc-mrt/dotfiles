--
-- Language servers.
--
-- Uses Neovim's built-in LSP client configuration (0.11+): `vim.lsp.config`
-- defines settings, `vim.lsp.enable` turns a server on. nvim-lspconfig is
-- still installed, but now only supplies the default cmd/root_markers for each
-- server — there is no `require('lspconfig').xxx.setup{}` call any more.
--
-- Keymaps live in keymaps.lua. See `:checkhealth vim.lsp` when a server
-- doesn't attach; the usual cause is the binary not being on $PATH.
--

-- ── Diagnostics ─────────────────────────────────────────────────────────────

vim.diagnostic.config({
  -- Show the message inline, but only for the line the cursor is on, so a
  -- file with many warnings stays readable.
  virtual_text = { current_line = true, source = 'if_many' },
  underline = true,
  severity_sort = true,
  update_in_insert = false,
  float = { border = 'rounded', source = 'if_many' },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN]  = '󰀪 ',
      [vim.diagnostic.severity.INFO]  = '󰋽 ',
      [vim.diagnostic.severity.HINT]  = '󰌶 ',
    },
  },
})

-- ── Per-server settings ─────────────────────────────────────────────────────

-- Hyprland ships Lua stubs for its config API. They only exist on the Linux
-- box; pointing lua_ls at a missing directory on macOS makes it log warnings
-- on every attach, so only add the path when it's actually there.
local lua_library = {}
if vim.fn.isdirectory("/usr/share/hypr/stubs") == 1 then
    table.insert(lua_library, "/usr/share/hypr/stubs")
end

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            workspace = {
                library = lua_library,
            },
            -- Stop lua_ls complaining about `vim` when editing this config.
            diagnostics = { globals = { "vim" } },
        },
    },
})

-- ── Enable ──────────────────────────────────────────────────────────────────
--
-- A server listed here but not installed is simply skipped (with a warning in
-- :messages), so it's safe to leave entries for languages you only sometimes
-- work in.
--
-- Worth adding once the binaries are installed:
--   bashls (bash-language-server), taplo (TOML), yamlls (yaml-language-server)
--
vim.lsp.enable({
  'lua_ls',
  'pyright',
  'gopls',
  'ts_ls',
  'jsonls',
  'rust_analyzer',
})

-- ── On attach ───────────────────────────────────────────────────────────────

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client == nil then return end

    -- Highlight other references to the symbol under the cursor after a pause.
    if client:supports_method('textDocument/documentHighlight') then
      local group = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        group = group, buffer = ev.buf, callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group, buffer = ev.buf, callback = vim.lsp.buf.clear_references,
      })
    end

    -- Inlay hints (parameter names, inferred types) where the server offers
    -- them. Toggle per buffer with <leader>uh.
    if client:supports_method('textDocument/inlayHint') then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
      vim.keymap.set('n', '<leader>uh', function()
        local on = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
        vim.lsp.inlay_hint.enable(not on, { bufnr = ev.buf })
      end, { buffer = ev.buf, desc = 'Toggle inlay hints' })
    end
  end,
})
