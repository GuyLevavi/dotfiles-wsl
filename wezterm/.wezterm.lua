-- =============================================================================
-- WezTerm Configuration
-- =============================================================================
-- Place this file in your Windows user home directory:
--   C:\Users\USERNAME\.wezterm.lua
--
-- This config targets a WSL2 workflow (Fedora/AlmaLinux) with GPU-accelerated
-- rendering, Tokyo Night theming, and vim-style pane navigation.
-- =============================================================================

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- -----------------------------------------------------------------------------
-- Font
-- -----------------------------------------------------------------------------
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 12

-- -----------------------------------------------------------------------------
-- Color Scheme
-- -----------------------------------------------------------------------------
-- Active scheme
-- config.color_scheme = "Catppuccin Mocha"

-- Uncomment ONE line below to switch. All options are WezTerm built-ins.

-- ── Standard themes ─────────────────────────────────────────────────
config.color_scheme = "Tokyo Night"
-- config.color_scheme = "Gruvbox dark, medium (base16)"

-- ── Colorblind-friendly themes (deuteranopia / protanopia) ──────────
-- These palettes avoid or reduce red-green distinctions.
-- Pair with a matching nvim colorscheme for consistency (see colorscheme.lua).
--
-- Nightfox family — designed with daltonization support in the nvim plugin.
-- These WezTerm extras ship with EdenEast/nightfox.nvim and use the same
-- palette, so terminal colors match your editor exactly.
-- config.color_scheme = "nightfox"              -- deep blue-purple, high contrast
-- config.color_scheme = "carbonfox"             -- neutral carbon/grey, minimal hue
-- config.color_scheme = "nordfox"               -- nord-inspired blue/cyan palette
-- config.color_scheme = "terafox"               -- warm forest green/amber
-- config.color_scheme = "duskfox"               -- soft purple/magenta twilight
--
-- Classic colorblind-safe palettes (blue-yellow/orange emphasis):
-- config.color_scheme = "Solarized Dark (Gogh)"   -- blue/yellow, designed for CVD
-- config.color_scheme = "Solarized Light (Gogh)"  -- light variant
-- config.color_scheme = "nord"                     -- muted blue/cyan, low red-green
-- config.color_scheme = "Tango (terminal.sexy)"    -- blue/orange GNOME palette

-- -----------------------------------------------------------------------------
-- Default Shell / WSL2
-- -----------------------------------------------------------------------------
-- Launch directly into the Fedora WSL2 distribution.
config.default_domain = "WSL:FedoraLinux-43"

-- If your distro is registered under a different name (e.g. AlmaLinux),
-- change the value above accordingly:
-- config.default_domain = "WSL:AlmaLinux"

-- -----------------------------------------------------------------------------
-- GPU Rendering
-- -----------------------------------------------------------------------------
-- WebGpu is fastest (uses dGPU when available). WezTerm auto-selects the best
-- GPU adapter. If you experience crashes, switch to "OpenGL" as a fallback.
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance" -- prefer dGPU over iGPU
-- config.front_end = "OpenGL"                     -- fallback if WebGpu crashes

-- Reduce input latency: don't wait to coalesce renders
config.max_fps = 120
config.animation_fps = 60

-- -----------------------------------------------------------------------------
-- Window Appearance
-- -----------------------------------------------------------------------------
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95
config.win32_system_backdrop = "Acrylic" -- blur effect on Windows

config.window_padding = {
  left = 4,
  right = 4,
  top = 4,
  bottom = 4,
}

-- -----------------------------------------------------------------------------
-- Tab Bar
-- -----------------------------------------------------------------------------
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true

-- -----------------------------------------------------------------------------
-- Mouse
-- -----------------------------------------------------------------------------
config.enable_scroll_bar = false
config.scrollback_lines = 10000

-- Allow scroll wheel to work inside alternate-screen programs (tmux, nvim, etc.)
config.bypass_mouse_reporting_modifiers = "SHIFT"

-- -----------------------------------------------------------------------------
-- Key Bindings
-- -----------------------------------------------------------------------------
local act = wezterm.action

config.keys = {
  -- Pane splitting
  {
    key = "|",
    mods = "CTRL|SHIFT",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "-",
    mods = "CTRL|SHIFT",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },

  -- Vim-style pane navigation
  {
    key = "h",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "j",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "k",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "l",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Right"),
  },

  -- Tab management
  {
    key = "t",
    mods = "CTRL|SHIFT",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  {
    key = "w",
    mods = "CTRL|SHIFT",
    action = act.CloseCurrentPane({ confirm = true }),
  },
  {
    key = "n",
    mods = "CTRL|SHIFT",
    action = act.ActivateTabRelative(1),
  },
  {
    key = "p",
    mods = "CTRL|SHIFT",
    action = act.ActivateTabRelative(-1),
  },

  -- Utilities
  {
    key = "f",
    mods = "CTRL|SHIFT",
    action = act.Search("CurrentSelectionOrEmptyString"),
  },
  {
    key = " ",
    mods = "CTRL|SHIFT",
    action = act.QuickSelect,
  },
  {
    key = "z",
    mods = "CTRL|SHIFT",
    action = act.TogglePaneZoomState,
  },

  -- Copy mode: enter vim-like visual selection in scrollback buffer.
  -- Use v/V for visual/line select, y to yank, Escape to exit.
  {
    key = "x",
    mods = "CTRL|SHIFT",
    action = act.ActivateCopyMode,
  },

  -- Shift+Arrow: enter copy mode and start selecting (like Windows Terminal).
  -- Once in copy mode, continue with Shift+Arrow or vim motions.
  {
    key = "LeftArrow",
    mods = "SHIFT",
    action = act.Multiple({
      act.ActivateCopyMode,
      act.CopyMode({ SetSelectionMode = "Cell" }),
      act.CopyMode("MoveLeft"),
    }),
  },
  {
    key = "RightArrow",
    mods = "SHIFT",
    action = act.Multiple({
      act.ActivateCopyMode,
      act.CopyMode({ SetSelectionMode = "Cell" }),
      act.CopyMode("MoveRight"),
    }),
  },
  {
    key = "UpArrow",
    mods = "SHIFT",
    action = act.Multiple({
      act.ActivateCopyMode,
      act.CopyMode({ SetSelectionMode = "Cell" }),
      act.CopyMode("MoveUp"),
    }),
  },
  {
    key = "DownArrow",
    mods = "SHIFT",
    action = act.Multiple({
      act.ActivateCopyMode,
      act.CopyMode({ SetSelectionMode = "Cell" }),
      act.CopyMode("MoveDown"),
    }),
  },
}

-- -----------------------------------------------------------------------------
-- Copy Mode Key Table
-- -----------------------------------------------------------------------------
-- Once in copy mode (Ctrl+Shift+X or Shift+Arrow), these keys are active.
-- Shift+Arrow continues selection, y copies, Escape exits.
config.key_tables = {
  copy_mode = {
    -- Shift+Arrow: extend selection
    { key = "LeftArrow", mods = "SHIFT", action = act.CopyMode("MoveLeft") },
    { key = "RightArrow", mods = "SHIFT", action = act.CopyMode("MoveRight") },
    { key = "UpArrow", mods = "SHIFT", action = act.CopyMode("MoveUp") },
    { key = "DownArrow", mods = "SHIFT", action = act.CopyMode("MoveDown") },

    -- Ctrl+Shift+Arrow: extend selection by word
    { key = "LeftArrow", mods = "CTRL|SHIFT", action = act.CopyMode("MoveBackwardWord") },
    { key = "RightArrow", mods = "CTRL|SHIFT", action = act.CopyMode("MoveForwardWord") },

    -- Arrow keys without shift: move cursor (adjusts selection end)
    { key = "LeftArrow", mods = "NONE", action = act.CopyMode("MoveLeft") },
    { key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
    { key = "UpArrow", mods = "NONE", action = act.CopyMode("MoveUp") },
    { key = "DownArrow", mods = "NONE", action = act.CopyMode("MoveDown") },

    -- Vim-style movement
    { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
    { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
    { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
    { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
    { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
    { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
    { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
    { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
    { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
    { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
    { key = "G", mods = "SHIFT", action = act.CopyMode("MoveToScrollbackBottom") },

    -- Selection modes
    { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
    { key = "V", mods = "SHIFT", action = act.CopyMode({ SetSelectionMode = "Line" }) },
    { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },

    -- Copy and exit
    {
      key = "y",
      mods = "NONE",
      action = act.Multiple({
        act.CopyTo("ClipboardAndPrimarySelection"),
        act.CopyMode("Close"),
      }),
    },
    { key = "Enter", mods = "NONE", action = act.Multiple({
      act.CopyTo("ClipboardAndPrimarySelection"),
      act.CopyMode("Close"),
    })},

    -- Exit copy mode
    { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
    { key = "q", mods = "NONE", action = act.CopyMode("Close") },

    -- Scrolling
    { key = "u", mods = "CTRL", action = act.CopyMode("PageUp") },
    { key = "d", mods = "CTRL", action = act.CopyMode("PageDown") },
  },
}

-- -----------------------------------------------------------------------------
-- Mouse Bindings
-- -----------------------------------------------------------------------------
config.mouse_bindings = {
  -- Right-click paste (common Windows expectation)
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = act.PasteFrom("Clipboard"),
  },
}

return config
