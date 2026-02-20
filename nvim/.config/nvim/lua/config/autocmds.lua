-- autocmds.lua - Automatic commands (event-driven actions)
-- =========================================================
-- This file is automatically loaded on the VeryLazy event.
--
-- Autocmds let you run code when specific events happen, like:
--   - Opening a Python file → set indentation to 4 spaces
--   - Saving a file → strip trailing whitespace
--   - Entering a terminal → switch to insert mode
--
-- FORMAT: vim.api.nvim_create_autocmd("EVENT", { pattern, callback })

-- ── Python File Settings ────────────────────────────────────────────
-- PEP 8 (Python style guide) requires 4-space indentation and
-- a max line length of 79 (though ruff/black default to 88).
-- We set these automatically for any .py file.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    -- opt_local sets options ONLY for the current buffer (file),
    -- not globally. This way, opening a YAML file afterward
    -- still uses 2-space indent.
    vim.opt_local.tabstop = 4       -- display tab as 4 spaces
    vim.opt_local.shiftwidth = 4    -- indent/outdent by 4 spaces
    vim.opt_local.softtabstop = 4   -- pressing Tab inserts 4 spaces
    vim.opt_local.expandtab = true  -- use spaces, never tab characters
    vim.opt_local.colorcolumn = "88" -- ruff/black default line length
  end,
  desc = "Set Python-specific indentation and column guide",
})

-- ── Highlight Yanked Text ───────────────────────────────────────────
-- When you yank (copy) text, briefly highlight what was copied.
-- This gives visual feedback so you know exactly what you grabbed.
-- Very helpful for beginners who are learning yank motions.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({
      higroup = "IncSearch", -- use the IncSearch highlight color
      timeout = 200,         -- highlight for 200 milliseconds
    })
  end,
  desc = "Briefly highlight yanked text",
})

-- ── Auto-Enter Insert Mode in Terminal ──────────────────────────────
-- When you open a terminal buffer (e.g., via <leader>rr to run Python),
-- automatically enter insert mode so you can interact with it immediately
-- instead of having to press `i` first.
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false          -- no line numbers in terminal
    vim.opt_local.relativenumber = false   -- no relative numbers either
    vim.cmd("startinsert")                 -- go to insert mode
  end,
  desc = "Auto-enter insert mode in terminal buffers",
})

-- ── Resize Splits on Window Resize ──────────────────────────────────
-- If you resize your terminal emulator, all Neovim splits resize
-- proportionally. Without this, one split might get squished.
vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
  desc = "Auto-resize splits when terminal is resized",
})

-- ── Close Certain Buffers with 'q' ─────────────────────────────────
-- Some buffer types (help pages, quickfix lists, etc.) should be
-- closable with just pressing 'q'. LazyVim handles many of these,
-- but we add a few extras common in Python development.
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "dap-float",      -- debugger floating windows
    "dap-repl",       -- debugger REPL (when not actively using it)
    "neotest-summary", -- test result summary
    "neotest-output",  -- test output
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
