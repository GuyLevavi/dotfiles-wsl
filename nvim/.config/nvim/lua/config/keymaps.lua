-- keymaps.lua - Custom key mappings
-- ==================================
-- LazyVim already provides excellent keymaps. Here we add extras
-- for Python development and convenience.
--
-- LazyVim defaults we rely on (do NOT duplicate):
--   <C-h/j/k/l>  window navigation
--   <A-j/k>      move lines up/down
--   < / >        visual indent (stays in visual mode)
--
-- TIP: Press <leader> (Space) and wait — which-key will show ALL
--      available keymaps organized by category.

local map = vim.keymap.set

-- ── Quick Save ──────────────────────────────────────────────────────
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- ── Python Execution ────────────────────────────────────────────────
-- Quick-run Python files without leaving Neovim. `%` = current file.
map("n", "<leader>rr", function()
  vim.cmd("split | terminal python3 " .. vim.fn.expand("%"))
end, { desc = "Run Python file in terminal" })

map("n", "<leader>rt", function()
  vim.cmd("split | terminal python3 -m pytest " .. vim.fn.expand("%") .. " -v")
end, { desc = "Run pytest on file" })

map("n", "<leader>rT", function()
  vim.cmd("split | terminal python3 -m pytest -v")
end, { desc = "Run all tests with pytest" })

-- ── Better Escape ───────────────────────────────────────────────────
-- Press "jk" quickly in insert mode to exit to normal mode.
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- ── Center After Jump ───────────────────────────────────────────────
-- Keep the cursor centered when jumping to prevent disorientation.
map("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

-- ── Quickfix Navigation ─────────────────────────────────────────────
map("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })
map("n", "[q", "<cmd>cprev<cr>zz", { desc = "Previous quickfix item" })
