-- init.lua - The entry point for Neovim configuration
-- =====================================================
-- This file is the FIRST thing Neovim reads when it starts.
-- We keep it minimal: it just loads our config/lazy.lua file,
-- which bootstraps the lazy.nvim plugin manager and LazyVim.
--
-- LazyVim handles everything else automatically:
--   config/options.lua  -> loaded BEFORE plugins
--   config/keymaps.lua  -> loaded on VeryLazy event (after UI is ready)
--   config/autocmds.lua -> loaded on VeryLazy event
--   plugins/*.lua       -> all plugin specs in lua/plugins/ are auto-loaded

require("config.lazy")
