-- options.lua - Neovim editor options
-- ====================================
-- This file is automatically loaded BEFORE lazy.nvim startup.
-- LazyVim sets many sensible defaults already. Here we override
-- or add options specific to our workflow.
--
-- TIP: Run `:set option?` in Neovim to check the current value of any option.
-- TIP: Run `:options` to browse ALL available options with descriptions.

local opt = vim.opt

-- ── Line Numbers ────────────────────────────────────────────────────
-- Relative line numbers show the distance from the current line.
-- This is incredibly useful for vim motions like `5j` (jump 5 lines down)
-- or `d3k` (delete 3 lines up). You can see the exact count at a glance.
opt.relativenumber = true   -- show relative numbers on other lines
-- Note: LazyVim already sets `number = true` so you still see the
-- absolute line number on the current line. The combo is called
-- "hybrid line numbers".

-- ── Scrolling ───────────────────────────────────────────────────────
-- Keep 8 lines visible above and below the cursor when scrolling.
-- Without this, the cursor can reach the very edge of the screen
-- before the view scrolls, making it hard to see context.
opt.scrolloff = 8

-- ── Text Display ────────────────────────────────────────────────────
-- conceallevel controls whether Neovim hides certain characters.
-- At level 2+ (LazyVim default), markdown bold markers ** are hidden,
-- JSON quotes might disappear, etc. For a beginner, this is confusing
-- because what you see doesn't match what's in the file.
-- Setting to 0 shows everything as-is.
opt.conceallevel = 0

-- ── Clipboard ───────────────────────────────────────────────────────
-- "unnamedplus" connects Neovim's yank/paste to your system clipboard.
-- This means:
--   - `yy` (yank a line) copies to system clipboard
--   - `p` (paste) pastes from system clipboard
--   - You can copy in Neovim and paste in your browser, and vice versa
-- Without this, Neovim uses its own internal registers and you'd need
-- `"+y` to yank to system clipboard (awkward for beginners).
opt.clipboard = "unnamedplus"

-- ── Search ──────────────────────────────────────────────────────────
-- LazyVim already sets ignorecase + smartcase, but let's be explicit:
-- ignorecase: searching for "hello" matches "Hello", "HELLO", etc.
-- smartcase: if you type a capital letter, search becomes case-sensitive.
--   e.g., "Hello" only matches "Hello", not "hello".
opt.ignorecase = true
opt.smartcase = true

-- ── Indentation ─────────────────────────────────────────────────────
-- Default indentation (Python-specific overrides are in autocmds.lua).
-- Most config files (YAML, JSON, Lua) use 2-space indentation.
opt.tabstop = 2        -- a tab character displays as 2 spaces
opt.shiftwidth = 2     -- indent/outdent by 2 spaces
opt.expandtab = true   -- pressing Tab inserts spaces, not a tab character

-- ── UI ──────────────────────────────────────────────────────────────
-- Show a vertical line at column 88 as a visual guide.
-- This matches ruff/black's default line length for Python.
-- For non-Python files, this is still a reasonable width.
opt.colorcolumn = "88"

-- Enable cursor line highlighting so you can easily find your cursor
opt.cursorline = true

-- Open new splits below and to the right (feels more natural)
opt.splitbelow = true
opt.splitright = true

-- ── File Handling ───────────────────────────────────────────────────
-- Don't create backup or swap files. Modern workflows use git for
-- version control, and swap files just create annoying prompts.
opt.swapfile = false
opt.backup = false

-- But DO keep undo history across sessions. This means you can
-- close a file, reopen it, and still undo previous changes.
opt.undofile = true

-- ── Disable Unused Providers ────────────────────────────────────────
-- Neovim supports remote plugins written in Python, Ruby, Perl, and Node.
-- We don't use any of those (we use LSP/DAP instead), so disable them
-- to silence checkhealth warnings and save a few ms on startup.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
