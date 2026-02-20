-- keymaps.lua - Custom key mappings
-- ==================================
-- This file is automatically loaded on the VeryLazy event (after UI is ready).
-- LazyVim already provides excellent keymaps. Here we add extras that are
-- useful for Python development and vim beginners.
--
-- TERMINOLOGY FOR BEGINNERS:
--   "n" = Normal mode (when you're navigating, not typing text)
--   "v" = Visual mode (when you've selected text)
--   "i" = Insert mode (when you're typing text)
--   "<leader>" = Space key (LazyVim sets this by default)
--   "<C-x>" = Ctrl+x
--   "<cr>" = Enter/Return key
--   "<cmd>...<cr>" = run a Neovim command
--
-- TIP: Press <leader> (Space) and wait — which-key will show you ALL
--      available keymaps organized by category. This is the #1 way to
--      discover what you can do!

local map = vim.keymap.set

-- ── Window Navigation ───────────────────────────────────────────────
-- Move between split windows with Ctrl+h/j/k/l instead of Ctrl-w then h/j/k/l.
-- LazyVim already sets these, but we include them explicitly so you
-- know they exist and can see the pattern.
--
-- Think of it like arrow keys: h=left, j=down, k=up, l=right
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- ── Quick Save ──────────────────────────────────────────────────────
-- Space+w saves the current file. Much faster than :w<Enter>.
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- ── Python Execution ────────────────────────────────────────────────
-- These let you quickly run Python files without leaving Neovim.
-- The `%` symbol means "the current file".
--
-- Space+r is our "run" prefix group.
map("n", "<leader>rr", function()
  -- Use the terminal to run the current Python file
  -- This opens a split terminal so you can see output and interact
  vim.cmd("split | terminal python3 " .. vim.fn.expand("%"))
end, { desc = "Run Python file in terminal" })

map("n", "<leader>rt", function()
  vim.cmd("split | terminal python3 -m pytest " .. vim.fn.expand("%") .. " -v")
end, { desc = "Run pytest on file" })

map("n", "<leader>rT", function()
  vim.cmd("split | terminal python3 -m pytest -v")
end, { desc = "Run all tests with pytest" })

-- ── Stay in Visual Mode After Indent ────────────────────────────────
-- By default, pressing > or < in visual mode to indent/outdent
-- exits visual mode. This keeps you in visual mode so you can
-- adjust the indentation multiple times.
map("v", "<", "<gv", { desc = "Outdent and reselect" })
map("v", ">", ">gv", { desc = "Indent and reselect" })

-- ── Move Lines Up/Down ──────────────────────────────────────────────
-- Alt+j/k moves the current line (or selected lines) up or down.
-- LazyVim has these already, but here for reference.
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- ── Better Escape ───────────────────────────────────────────────────
-- Pressing "jk" quickly in insert mode exits to normal mode.
-- This saves you from reaching for the Escape key constantly.
-- If you actually need to type "jk", just type slower.
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- ── Center After Jump ───────────────────────────────────────────────
-- After jumping half-page up/down or to search results, center the
-- screen on the cursor. This prevents disorientation.
map("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

-- ── Quickfix Navigation ─────────────────────────────────────────────
-- Navigate through error lists, search results, etc.
-- These are useful when you have a list of diagnostics or grep results.
map("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })
map("n", "[q", "<cmd>cprev<cr>zz", { desc = "Previous quickfix item" })
