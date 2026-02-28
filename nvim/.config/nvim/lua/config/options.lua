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
-- CLIPBOARD CONFIGURATION FOR WSL/Windows/Headless
-- ═════════════════════════════════════════════════════════════════════
-- Delete operations use internal nvim clipboard (dd, x)
-- Yank operations use system clipboard (+ register) when available
-- Gracefully handles headless contexts (WSL, Docker, RunAI)

-- Detect environment
local is_wsl = vim.fn.has("wsl") == 1 or vim.env.WSL_DISTRO_NAME ~= nil
local has_display = vim.env.DISPLAY ~= nil or vim.env.WAYLAND_DISPLAY ~= nil
local is_headless = not has_display and not is_wsl

if is_wsl then
  -- WSL clipboard integration via Windows clip.exe
  -- Works even in headless WSL because clip.exe talks to Windows
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
elseif has_display then
  -- Native Linux with display - use xclip
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
else
  -- Headless environment (no display) - use internal clipboard only
  -- No system clipboard provider to avoid errors
  vim.g.clipboard = nil
  vim.notify("Running in headless mode - using internal clipboard only", vim.log.levels.INFO)
end

-- Don't use unnamedplus by default - keeps delete/x operations internal
opt.clipboard = ""

-- ── Keymaps for Clipboard ───────────────────────────────────────────
-- Only use system clipboard (+ register) if provider is available
-- Otherwise use internal nvim clipboard

if vim.g.clipboard then
  -- System clipboard available - map yank to use it
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
else
  -- No system clipboard - use internal only
  -- Default vim yank/delete behavior (unnamed register)
  vim.notify("Clipboard: using internal nvim clipboard (no system integration)", vim.log.levels.INFO)
end

-- ═════════════════════════════════════════════════════════════════════
-- AUTOSAVE CONFIGURATION
-- ═════════════════════════════════════════════════════════════════════
-- Auto-save buffers when leaving insert mode or changing buffers
-- but DO NOT auto-format on save (formatting is manual with <leader>cf)

-- Enable auto-write (save when switching buffers, leaving insert, etc.)
opt.autowrite = true
opt.autowriteall = true

-- Disable autoformat on save
-- Formatting is controlled by conform.nvim and will be manual only
vim.g.autoformat = false

-- Set up auto-save trigger on insert mode leave and text changes
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  pattern = "*",
  callback = function()
    -- Only save if buffer is modified and not read-only
    if vim.bo.modified and not vim.bo.readonly and vim.fn.expand("%") ~= "" then
      vim.api.nvim_command("silent! write")
    end
  end,
  desc = "Auto-save on insert leave and text change",
})
