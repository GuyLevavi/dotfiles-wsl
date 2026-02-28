-- mason-tools.lua - Pre-install Mason packages for airgap
-- =========================================================
-- All tools needed for the development environment.
--
-- IMPORTANT: This file MUST load AFTER LazyVim extras to override
-- their automatic_installation = true settings. We explicitly
-- control ALL package installations via mason-tool-installer.

return {
  -- First: Override mason-lspconfig to disable ALL auto-installation
  -- This must come AFTER the extras to take effect
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      -- Completely disable automatic installation
      -- This overrides any settings from LazyVim extras
      opts.automatic_installation = false
      -- Also ensure we don't auto-install any servers
      opts.ensure_installed = opts.ensure_installed or {}
    end,
  },

  -- Second: Override mason-nvim-dap to disable auto-install
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts)
      opts.automatic_installation = false
      opts.ensure_installed = opts.ensure_installed or {}
    end,
  },

  -- Third: mason-tool-installer for our explicit list
  -- This is the ONLY thing that should install packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason.nvim" },
    opts = {
      ensure_installed = {
        -- Python LSP and tools
        "basedpyright",
        "ruff",
        "debugpy",
        -- YAML / JSON / Docker
        "yaml-language-server",
        "json-lsp",
        "dockerfile-language-server",
        -- Markdown (linting only, no LSP)
        "markdownlint-cli2",
        "markdown-toc",
        -- Shell/Code quality
        "shfmt",
        "stylua",
        "hadolint",
        "tree-sitter-cli",
      },
      -- Disable automatic installation - we only install what's in ensure_installed
      automatic_installation = false,
    },
  },
}
