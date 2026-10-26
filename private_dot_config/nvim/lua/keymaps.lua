--
-- Keymaps.
--
-- Every mapping carries a `desc`, because mini.clue renders those descriptions
-- when you press a prefix and pause. Press <Space> and wait to see the menu.
--
-- Deliberately NOT redefined here (Neovim 0.11+ ships them, and relearning
-- them costs nothing):
--   K     hover docs            grn   rename symbol
--   grr   references            gra   code action
--   gri   implementation        gO    document symbols
--   ]d [d next/prev diagnostic  (also via mini.bracketed: ]b ]q ]c …)
--

local map = function(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend('force', { silent = true, desc = desc }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- ── Basics ──────────────────────────────────────────────────────────────────

map('n', '<Esc>', '<cmd>nohlsearch<cr>', 'Clear search highlight')
map('n', '<leader>w', '<cmd>write<cr>', 'Write file')
map('n', '<leader>q', '<cmd>quit<cr>', 'Quit window')

-- Keep the cursor centred when paging and jumping through search results.
map('n', '<C-d>', '<C-d>zz', 'Half page down (centred)')
map('n', '<C-u>', '<C-u>zz', 'Half page up (centred)')
map('n', 'n', 'nzzzv', 'Next match (centred)')
map('n', 'N', 'Nzzzv', 'Prev match (centred)')

-- Indent repeatedly without losing the selection.
map('x', '<', '<gv', 'Outdent selection')
map('x', '>', '>gv', 'Indent selection')

-- Paste over a selection without clobbering the unnamed register.
map('x', 'p', 'P', 'Paste without yanking replaced text')

-- ── Find (<leader>f) ────────────────────────────────────────────────────────
--
-- mini.pick. Inside a picker: <C-n>/<C-p> move, <CR> confirm,
-- <C-s>/<C-v> open in a horizontal/vertical split, <C-w> delete a word.

map('n', '<leader><leader>', function() MiniPick.builtin.buffers() end, 'Switch buffer')
map('n', '<leader>ff', function() MiniPick.builtin.files() end, 'Find files')
map('n', '<leader>fg', function() MiniPick.builtin.grep_live() end, 'Grep (live)')
map('n', '<leader>fw', function() MiniPick.builtin.grep({ pattern = vim.fn.expand('<cword>') }) end, 'Grep word under cursor')
map('n', '<leader>fh', function() MiniPick.builtin.help() end, 'Help tags')
map('n', '<leader>fb', function() MiniPick.builtin.buffers() end, 'Buffers')
map('n', '<leader>fr', function() MiniExtra.pickers.oldfiles() end, 'Recent files')
map('n', '<leader>fl', function() MiniExtra.pickers.buf_lines({ scope = 'current' }) end, 'Lines in buffer')
map('n', '<leader>fk', function() MiniExtra.pickers.keymaps() end, 'Keymaps')
map('n', '<leader>fd', function() MiniExtra.pickers.diagnostic() end, 'Diagnostics')
map('n', '<leader>fG', function() MiniExtra.pickers.git_files() end, 'Git-tracked files')

-- File explorer. The second call opens focused on the current file, which is
-- usually what you want when you're already editing something.
map('n', '<leader>e', function() MiniFiles.open() end, 'Explorer (cwd)')
map('n', '<leader>E', function()
  MiniFiles.open(vim.api.nvim_buf_get_name(0), true)
end, 'Explorer (current file)')

-- ── LSP (<leader>l) ─────────────────────────────────────────────────────────

map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
map('n', 'gy', vim.lsp.buf.type_definition, 'Go to type definition')

map('n', '<leader>lr', vim.lsp.buf.rename, 'Rename symbol')
map('n', '<leader>la', vim.lsp.buf.code_action, 'Code action')
map('n', '<leader>ls', function() MiniExtra.pickers.lsp({ scope = 'document_symbol' }) end, 'Document symbols')
map('n', '<leader>lS', function() MiniExtra.pickers.lsp({ scope = 'workspace_symbol' }) end, 'Workspace symbols')
map('n', '<leader>ld', function() MiniExtra.pickers.diagnostic({ scope = 'current' }) end, 'Buffer diagnostics')
map('n', '<leader>le', vim.diagnostic.open_float, 'Show diagnostic under cursor')
map('n', '<leader>lf', function() require('conform').format({ async = true }) end, 'Format buffer')
map('n', '<leader>li', function() vim.cmd('checkhealth vim.lsp') end, 'LSP health')

-- ── Git (<leader>g) ─────────────────────────────────────────────────────────

map('n', '<leader>gd', function() MiniDiff.toggle_overlay(0) end, 'Toggle diff overlay')
map('n', '<leader>gs', '<cmd>Git status<cr>', 'Git status')
map('n', '<leader>gl', '<cmd>Git log --oneline -20<cr>', 'Git log')
map('n', '<leader>gb', '<cmd>Git blame -- %<cr>', 'Git blame file')

-- ── Buffers (<leader>b) ─────────────────────────────────────────────────────

map('n', '<leader>bd', '<cmd>bdelete<cr>', 'Delete buffer')
map('n', '<leader>bD', '<cmd>bdelete!<cr>', 'Delete buffer (force)')
map('n', '<leader>bn', '<cmd>bnext<cr>', 'Next buffer')
map('n', '<leader>bp', '<cmd>bprevious<cr>', 'Previous buffer')

-- ── Toggles (<leader>u) ─────────────────────────────────────────────────────

map('n', '<leader>uf', function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify('Autoformat ' .. (vim.g.disable_autoformat and 'disabled' or 'enabled'))
end, 'Toggle autoformat')

map('n', '<leader>uw', function()
  vim.opt.wrap = not vim.opt.wrap:get()
end, 'Toggle wrap')

map('n', '<leader>us', function()
  vim.opt.spell = not vim.opt.spell:get()
end, 'Toggle spellcheck')

map('n', '<leader>ud', function()
  local enabled = vim.diagnostic.is_enabled()
  vim.diagnostic.enable(not enabled)
  vim.notify('Diagnostics ' .. (enabled and 'disabled' or 'enabled'))
end, 'Toggle diagnostics')
