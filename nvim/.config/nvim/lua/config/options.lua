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

-- ═════════════════════════════════════════════════════════════════════
-- CLIPBOARD CONFIGURATION FOR WSL/Windows
-- ═════════════════════════════════════════════════════════════════════
-- Delete operations use internal nvim clipboard (dd, x)
-- Yank operations use system clipboard (+ register) for Windows access

-- Detect if we're in WSL
local is_wsl = vim.fn.has("wsl") == 1 or vim.env.WSL_DISTRO_NAME ~= nil

if is_wsl then
  -- WSL clipboard integration via Windows clip.exe
  -- Allows yanking from nvim in WSL and pasting in Windows apps
  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = 'powershell.exe -NoProfile -c "Get-Clipboard | Write-Host -NoNewline"',
      ["*"] = 'powershell.exe -NoProfile -c "Get-Clipboard | Write-Host -NoNewline"',
    },
    cache_enabled = true,
  }
else
  -- Native Linux - try to use xclip or xsel if available
  vim.g.clipboard = {
    name = "XClip",
    copy = {
      ["+"] = "xclip -selection clipboard",
      ["*"] = "xclip -selection primary",
    },
    paste = {
      ["+"] = "xclip -selection clipboard -o",
      ["*"] = "xclip -selection primary -o",
    },
    cache_enabled = true,
  }
end

-- Don't use unnamedplus by default - keeps delete/x operations internal
-- We'll explicitly map yank to use system clipboard
opt.clipboard = ""

-- ── Keymaps for Clipboard ───────────────────────────────────────────
-- Yank to system clipboard (+ register)
vim.keymap.set({ "n", "v" }, "y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "yy", '"+yy', { desc = "Yank line to system clipboard" })
vim.keymap.set("n", "Y", '"+Y', { desc = "Yank to EOL to system clipboard" })

-- Visual mode yank also goes to system clipboard
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Yank selection to system clipboard" })

-- Copy entire file to system clipboard
vim.keymap.set("n", "<leader>ya", 'gg"+yG', { desc = "Yank entire file to system clipboard" })

-- Delete/cut to system clipboard (optional - use <leader>d to cut)
vim.keymap.set({ "n", "v" }, "<leader>d", '"+d', { desc = "Cut to system clipboard" })
vim.keymap.set("n", "<leader>dd", '"+dd', { desc = "Cut line to system clipboard" })

-- Paste from system clipboard
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste before from system clipboard" })
