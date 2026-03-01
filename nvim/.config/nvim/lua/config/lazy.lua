-- lazy.lua - Bootstrap lazy.nvim plugin manager and configure LazyVim
-- ====================================================================
-- This file does three things:
--   1. Downloads lazy.nvim if it's not already installed (bootstrap)
--   2. Adds lazy.nvim to Neovim's runtime path so it can be loaded
--   3. Calls lazy.nvim's setup with our plugin specs and LazyVim extras
--
-- You almost never need to edit this file. To add plugins, create files
-- in lua/plugins/ instead.

-- Step 1: Bootstrap lazy.nvim
-- "lazypath" is where lazy.nvim will live on disk.
-- vim.fn.stdpath("data") is typically ~/.local/share/nvim on Linux/Mac
-- or ~/AppData/Local/nvim-data on Windows.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- lazy.nvim is not installed yet, so clone it from GitHub.
  -- In an airgapped environment, you'd pre-populate this path instead.
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone",
    "--filter=blob:none",       -- partial clone (saves bandwidth)
    "--branch=stable",          -- use the latest stable release
    lazyrepo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                             "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Step 2: Prepend lazy.nvim to the runtime path so Neovim can find it.
-- rtp = "runtime path" — the list of directories Neovim searches for
-- Lua modules, syntax files, etc.
vim.opt.rtp:prepend(lazypath)

-- Step 3: Configure lazy.nvim with LazyVim and our plugins
require("lazy").setup({
  -- The main LazyVim plugin spec. This gives us the full LazyVim
  -- distribution: default keymaps, UI, LSP setup, and more.
  spec = {
    {
      "LazyVim/LazyVim",
      import = "lazyvim.plugins",  -- import all default LazyVim plugins
      opts = {},
    },

    -- ── LazyVim Extras ──────────────────────────────────────────────
    -- "Extras" are optional plugin groups curated by LazyVim.
    -- Each one sets up an LSP server, formatter, linter, or tool
    -- so you don't have to configure them manually.

    -- Python: pyright (type checking) + ruff (linting & formatting)
    { import = "lazyvim.plugins.extras.lang.python" },

    -- Docker: Dockerfile LSP for syntax/linting in Dockerfiles
    { import = "lazyvim.plugins.extras.lang.docker" },

    -- YAML: yaml-language-server (great for docker-compose, k8s manifests)
    { import = "lazyvim.plugins.extras.lang.yaml" },

    -- JSON: json-language-server (schema validation, completion)
    { import = "lazyvim.plugins.extras.lang.json" },

    -- DAP (Debug Adapter Protocol): the foundation for debugging in Neovim
    -- This sets up the UI, virtual text, keymaps for breakpoints, etc.
    { import = "lazyvim.plugins.extras.dap.core" },

    -- mini-files: a simple file explorer you open with <leader>fm
    -- Lighter alternative to neo-tree; great for quick file operations
    { import = "lazyvim.plugins.extras.editor.mini-files" },

    -- mini-hipatterns: highlight color codes (#ff0000) and patterns inline
    { import = "lazyvim.plugins.extras.util.mini-hipatterns" },

    -- ── Your custom plugins ─────────────────────────────────────────
    -- Everything in lua/plugins/*.lua is automatically imported.
    -- Each file should return a table (or list of tables) of plugin specs.
    { import = "plugins" },
  },

  -- Default options for all plugin specs
  defaults = {
    -- By default, LazyVim plugins are lazy-loaded. This is good for
    -- startup performance — plugins only load when needed.
    lazy = false,
    -- Always use the latest version of LazyVim plugins (recommended).
    -- Set to false if you prefer pinning to stable releases.
    version = false,
  },

  -- Check for plugin updates automatically (shows a notification)
  checker = {
    enabled = true,
    notify = true,
  },

  -- Don't notify on config file changes (less noise)
  change_detection = {
    notify = false,
  },

  -- Performance optimizations
  performance = {
    rtp = {
      -- Disable some built-in Neovim plugins we don't need.
      -- This speeds up startup slightly.
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },

  -- Disable luarocks integration (we don't use any luarocks-based plugins)
  rocks = {
    enabled = false,
  },
})
