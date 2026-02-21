-- options.lua - Neovim editor options
-- ====================================
-- LazyVim sets many sensible defaults. Here we ONLY override or add
-- options specific to our workflow. Run `:set option?` to check any value.
--
-- LazyVim defaults we rely on (do NOT duplicate):
--   number, relativenumber, ignorecase, smartcase, cursorline,
--   splitbelow, splitright, undofile, clipboard, tabstop, shiftwidth,
--   expandtab, scrolloff (4)

local opt = vim.opt

-- ── Scrolling ───────────────────────────────────────────────────────
-- Override LazyVim's scrolloff=4 to keep more context visible.
opt.scrolloff = 8

-- ── Text Display ────────────────────────────────────────────────────
-- LazyVim defaults to conceallevel=2 (hides markdown bold markers,
-- JSON quotes, etc.). Show everything as-is for clarity.
opt.conceallevel = 0

-- ── Tab / Whitespace Characters ─────────────────────────────────────
-- Show tabs and trailing spaces with subtle symbols instead of '>'.
opt.listchars = { tab = "··", trail = "·", nbsp = "␣" }

-- ── UI ──────────────────────────────────────────────────────────────
-- Column guide at 88 (ruff/black default line length for Python).
opt.colorcolumn = "88"

-- ── File Handling ───────────────────────────────────────────────────
-- Don't create backup or swap files. We use git for version control.
opt.swapfile = false
opt.backup = false

-- ── Disable Unused Providers ────────────────────────────────────────
-- Silence checkhealth warnings for providers we don't use.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
