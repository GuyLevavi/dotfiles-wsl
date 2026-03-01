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

-- ── LazyVim Plugin Globals ───────────────────────────────────────────
-- These MUST live here (not in lua/plugins/*.lua) because LazyVim's
-- extras read them at spec-load time, before plugin files are evaluated.
--
-- Use basedpyright instead of the default pyright for Python LSP.
-- basedpyright is a stricter, actively maintained fork of pyright.
vim.g.lazyvim_python_lsp = "basedpyright"

-- ── Disable Unused Providers ────────────────────────────────────────
-- Silence checkhealth warnings for providers we don't use.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- ═════════════════════════════════════════════════════════════════════
-- CLIPBOARD CONFIGURATION FOR WSL/Windows/Docker/Linux Desktop
-- ═════════════════════════════════════════════════════════════════════
-- Delete operations use internal nvim clipboard (dd, x)
-- Yank operations use system clipboard (+ register) when available
-- Gracefully handles all contexts (WSL, Docker, Linux desktop, Ghostty)

-- Detect environment
local is_wsl = vim.fn.has("wsl") == 1 or vim.env.WSL_DISTRO_NAME ~= nil
local is_docker = vim.fn.filereadable("/.dockerenv") == 1 or vim.env.CONTAINER_ID ~= nil
local is_x11 = vim.env.DISPLAY ~= nil
local is_wayland = vim.env.WAYLAND_DISPLAY ~= nil
local has_display = is_x11 or is_wayland

if is_wsl then
  -- WSL clipboard detection order (best → worst):
  --   1. win32yank.exe  — bidirectional, fast. Needs manual setup:
  --      ln -s "/mnt/c/Program Files/Neovim/bin/win32yank.exe" ~/.local/bin/win32yank.exe
  --   2. xclip          — bidirectional via WSLg X11 (DISPLAY=:0 is set in WSLg).
  --      Install: sudo apt install xclip
  --   3. full-path clip.exe — copy-only fallback.
  --      appendWindowsPath=false in /etc/wsl.conf means bare "clip.exe" is NOT in PATH.
  if vim.fn.executable("win32yank.exe") == 1 then
    vim.g.clipboard = {
      name = "win32yank-wsl",
      copy = {
        ["+"] = "win32yank.exe -i --crlf",
        ["*"] = "win32yank.exe -i --crlf",
      },
      paste = {
        ["+"] = "win32yank.exe -o --lf",
        ["*"] = "win32yank.exe -o --lf",
      },
      cache_enabled = 0,  -- CRITICAL: cache_enabled=1 causes ~10 second delays
    }
  elseif vim.fn.executable("xclip") == 1 then
    -- xclip works via WSLg's X11 socket (DISPLAY=:0). Bidirectional.
    vim.g.clipboard = {
      name = "xclip",
      copy = {
        ["+"] = "xclip -selection clipboard",
        ["*"] = "xclip -selection primary",
      },
      paste = {
        ["+"] = "xclip -selection clipboard -o",
        ["*"] = "xclip -selection primary -o",
      },
      cache_enabled = 1,
    }
  elseif vim.fn.executable("/mnt/c/Windows/System32/clip.exe") == 1 then
    -- Last resort: full-path clip.exe. Copy-only (paste uses powershell).
    -- Bare "clip.exe" fails because appendWindowsPath=false in /etc/wsl.conf.
    vim.g.clipboard = {
      name = "WslClipboard",
      copy = {
        ["+"] = "/mnt/c/Windows/System32/clip.exe",
        ["*"] = "/mnt/c/Windows/System32/clip.exe",
      },
      paste = {
        ["+"] = 'powershell.exe -NoProfile -c "Get-Clipboard | Write-Host -NoNewline"',
        ["*"] = 'powershell.exe -NoProfile -c "Get-Clipboard | Write-Host -NoNewline"',
      },
      cache_enabled = 0,  -- CRITICAL: cache_enabled=1 causes ~10 second delays
    }
  else
    vim.notify(
      "WSL clipboard: no provider found. Install xclip: sudo apt install xclip",
      vim.log.levels.WARN
    )
  end
elseif is_x11 then
  -- Native Linux with X11 - use xclip
  vim.g.clipboard = {
    name = "xclip",
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
elseif is_wayland then
  -- Native Linux with Wayland - use wl-copy
  vim.g.clipboard = {
    name = "wl-copy",
    copy = {
      ["+"] = "wl-copy",
      ["*"] = "wl-copy",
    },
    paste = {
      ["+"] = "wl-paste",
      ["*"] = "wl-paste",
    },
    cache_enabled = true,
  }
else
  -- Docker or headless - try OSC52 as fallback
  -- OSC52 uses terminal escape sequences
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC52",
    copy = {
      ["+"] = osc52.copy,
      ["*"] = osc52.copy,
    },
    paste = {
      ["+"] = osc52.paste,
      ["*"] = osc52.paste,
    },
    cache_enabled = true,
  }
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
