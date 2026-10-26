--
-- Plugins.
--
-- Managed by vim.pack, Neovim's built-in manager (0.12+). No third-party
-- plugin manager involved.
--
--   :lua vim.pack.update()          update everything, review in a diff buffer
--   :lua vim.pack.del({ 'name' })   remove a plugin you've dropped below
--
-- Almost everything here comes from mini.nvim, which is a collection of small
-- independent modules rather than one big plugin. Each `require('mini.x')`
-- below is opt-in; nothing loads that you didn't ask for.
--

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
  'https://github.com/stevearc/conform.nvim',
})

-- ── Foundations ─────────────────────────────────────────────────────────────

-- Sensible mappings and autocommands. `options = { basic = false }` because
-- options.lua owns every option; without this, mini.basics would quietly
-- overwrite some of them at load time.
--
-- move_with_alt is off on purpose: Ghostty binds alt+arrows to switch terminal
-- splits, so Alt-based mappings inside nvim are a confusing overlap.
require('mini.basics').setup({
  options     = { basic = false },
  mappings    = { basic = true, windows = true, move_with_alt = false },
  autocommands = { basic = true },
})

-- Icons. mock_nvim_web_devicons() makes plugins that expect the older
-- nvim-web-devicons plugin use mini.icons instead, so we only ship one.
require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons()

require('mini.notify').setup()
vim.notify = MiniNotify.make_notify()   -- route vim.notify through mini.notify

require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.starter').setup()

-- ── Editing ─────────────────────────────────────────────────────────────────

require('mini.surround').setup()   -- sa/sd/sr to add/delete/replace surroundings
require('mini.pairs').setup()      -- auto-close brackets and quotes
require('mini.splitjoin').setup()  -- gS toggles a list between one and many lines
require('mini.trailspace').setup() -- highlights trailing whitespace

-- Better text objects: gives you things like `ci(`, `daf` (a function),
-- `vaa` (an argument), with treesitter awareness.
require('mini.ai').setup({ n_lines = 500 })

-- Move lines/selections with Alt-hjkl replacement: here it's <M-…> free, so
-- mini.move uses its defaults on visual selections and normal lines.
require('mini.move').setup()

-- ]b [b ]q [q ]d [d … jump between buffers, quickfix entries, diagnostics.
require('mini.bracketed').setup()

-- ── Navigation ──────────────────────────────────────────────────────────────

-- Fuzzy picker. Keymaps live in keymaps.lua.
require('mini.pick').setup()

-- Extra pickers (diagnostics, LSP symbols, git files, old files) that plug
-- into mini.pick.
require('mini.extra').setup()

-- File explorer as a navigable buffer: edit the filesystem like text, then
-- press `=` to apply. Far closer to vim's model than a sidebar tree.
require('mini.files').setup({
  windows = { preview = true, width_preview = 60 },
})

-- ── Git ─────────────────────────────────────────────────────────────────────

require('mini.diff').setup()  -- inline hunk signs; <leader>gd toggles an overlay
require('mini.git').setup()   -- :Git command and buffer-local git data

-- ── Completion ──────────────────────────────────────────────────────────────

-- LSP-aware completion with signature help and documentation popups.
-- Uses Neovim's built-in completion engine underneath, no external engine.
require('mini.completion').setup({
  delay = { completion = 100, info = 100, signature = 50 },
})

-- ── Key discovery ───────────────────────────────────────────────────────────

-- Press a prefix (<leader>, g, z, …) and wait `timeoutlen` — mini.clue shows
-- what's available. This is the single most useful module while you're still
-- learning the keymap.
local clue = require('mini.clue')
clue.setup({
  triggers = {
    { mode = 'n', keys = '<Leader>' },
    { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' },
    { mode = 'x', keys = 'g' },
    { mode = 'n', keys = 'z' },
    { mode = 'x', keys = 'z' },
    { mode = 'n', keys = ']' },
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = '"' },      -- registers
    { mode = 'x', keys = '"' },
    { mode = 'n', keys = "'" },      -- marks
    { mode = 'n', keys = '`' },
    { mode = 'i', keys = '<C-x>' },  -- built-in completion sources
    { mode = 'c', keys = '<C-r>' },
  },
  clues = {
    clue.gen_clues.builtin_completion(),
    clue.gen_clues.g(),
    clue.gen_clues.marks(),
    clue.gen_clues.registers(),
    clue.gen_clues.windows(),
    clue.gen_clues.z(),
    -- Group names for the <leader> menus defined in keymaps.lua
    { mode = 'n', keys = '<Leader>f', desc = '+find' },
    { mode = 'n', keys = '<Leader>g', desc = '+git' },
    { mode = 'n', keys = '<Leader>l', desc = '+lsp' },
    { mode = 'n', keys = '<Leader>b', desc = '+buffer' },
    { mode = 'n', keys = '<Leader>u', desc = '+toggle' },
  },
  window = { config = { width = 'auto' } },
})

-- ── Treesitter ──────────────────────────────────────────────────────────────

require('nvim-treesitter.config').setup({
  ensure_installed = {
    'toml', 'lua', 'python', 'go', 'typescript', 'json', 'javascript', 'rust',
    'tsx', 'yaml', 'markdown', 'markdown_inline', 'bash', 'kdl', 'gitcommit',
    'diff', 'dockerfile', 'sql', 'html', 'css',
  },
  auto_install = true,
  highlight = { enable = true },
  -- NOTE: treesitter-based `indent` is deliberately NOT enabled here. The
  -- option lives in a different place on nvim-treesitter's master vs main
  -- branch and I couldn't verify which your pinned rev expects. If you want
  -- it, check `:h nvim-treesitter` for your version first.
})

-- ── Formatting ──────────────────────────────────────────────────────────────

-- conform runs a real formatter when one is installed and falls back to the
-- language server otherwise, so this works before you've installed anything.
-- Autoformat is on but gated behind vim.g.disable_autoformat, toggled with
-- <leader>uf — useful in repos whose style you don't control.
require('conform').setup({
  formatters_by_ft = {
    lua        = { 'stylua' },
    python     = { 'ruff_format' },
    go         = { 'gofmt' },
    rust       = { 'rustfmt' },
    sh         = { 'shfmt' },
    javascript = { 'prettierd', 'prettier', stop_after_first = true },
    typescript = { 'prettierd', 'prettier', stop_after_first = true },
    typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
    json       = { 'prettierd', 'prettier', stop_after_first = true },
    yaml       = { 'prettierd', 'prettier', stop_after_first = true },
    markdown   = { 'prettierd', 'prettier', stop_after_first = true },
  },
  default_format_opts = { lsp_format = 'fallback' },
  format_on_save = function(bufnr)
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
      return nil
    end
    return { timeout_ms = 500 }
  end,
})
