-- autocmds.lua - Automatic commands (event-driven actions)
-- =========================================================
-- LazyVim defaults we rely on (do NOT duplicate):
--   TextYankPost highlight, VimResized split equalize,
--   close-with-q for help/qf/etc.

-- ── Python File Settings ────────────────────────────────────────────
-- PEP 8 requires 4-space indentation. ruff/black default to 88 columns.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
    vim.opt_local.colorcolumn = "88"
  end,
  desc = "Set Python-specific indentation and column guide",
})

-- ── Auto-Enter Insert Mode in Terminal ──────────────────────────────
-- When opening a terminal buffer (e.g., via <leader>rr), automatically
-- enter insert mode and hide line numbers.
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.cmd("startinsert")
  end,
  desc = "Auto-enter insert mode in terminal buffers",
})

-- ── Close DAP/Test Windows with 'q' ────────────────────────────────
-- LazyVim handles help, qf, etc. We add Python-specific buffer types.
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "dap-float",
    "dap-repl",
    "neotest-summary",
    "neotest-output",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", {
      buffer = event.buf,
      silent = true,
      desc = "Close this window with q",
    })
  end,
  desc = "Close DAP/test windows with q",
})
