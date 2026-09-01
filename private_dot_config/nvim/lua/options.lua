--
-- Editor options.
--
-- This file owns *every* option. mini.basics is configured with
-- `options = { basic = false }` in plugins.lua precisely so nothing here gets
-- silently overwritten by a plugin loading later — if an option surprises you,
-- it is in this file and nowhere else.
--

-- Leader keys. Must be set before any plugin defines a <leader> mapping,
-- which is why options.lua is the first require in init.lua.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local o = vim.opt

-- ── Appearance ──────────────────────────────────────────────────────────────
o.termguicolors  = true
o.number         = true
o.relativenumber = true   -- relative line numbers make 5j / 12k natural
o.signcolumn     = "yes"  -- always on, so text doesn't jump when a sign appears
o.cursorline     = true
o.scrolloff      = 8      -- keep 8 lines of context above/below the cursor
o.sidescrolloff  = 8
o.wrap           = false
o.pumheight      = 12     -- cap completion popup height
o.winborder      = "rounded"  -- 0.11+: one setting styles every floating window
o.showmode       = false  -- mini.statusline already shows the mode

-- Render whitespace that usually matters when it's wrong.
o.list           = true
o.listchars      = { tab = "» ", trail = "·", nbsp = "␣" }

-- ── Indentation ─────────────────────────────────────────────────────────────
o.tabstop        = 4
o.shiftwidth     = 4
o.expandtab      = true
o.smartindent    = true
o.breakindent    = true   -- wrapped lines keep their indent

-- ── Search ──────────────────────────────────────────────────────────────────
o.ignorecase     = true
o.smartcase      = true   -- ...unless the query contains a capital letter
o.incsearch      = true
o.inccommand     = "split"  -- live preview of :%s/// in a split

-- ── Splits ──────────────────────────────────────────────────────────────────
o.splitright     = true
o.splitbelow     = true
o.splitkeep      = "screen"  -- don't scroll existing windows when splitting

-- ── Files & undo ────────────────────────────────────────────────────────────
o.undofile       = true   -- undo history survives closing the file
o.undolevels     = 10000
o.swapfile       = false  -- undofile + git make this mostly noise
o.confirm        = true   -- prompt to save instead of failing on :q

-- ── Behaviour ───────────────────────────────────────────────────────────────
o.mouse          = "a"
o.updatetime     = 250    -- how long before CursorHold fires (diagnostics, etc.)
o.timeoutlen     = 400    -- how long to wait for a mapping sequence; also how
                          -- long until mini.clue pops up its key hints
o.completeopt    = { "menuone", "noselect" }
o.virtualedit    = "block"  -- let visual-block select past end of line
o.clipboard      = "unnamedplus"  -- share the system clipboard

-- Persist marks/registers/etc, but keep it modest.
o.shada          = { "'100", "<50", "s10", "h" }
