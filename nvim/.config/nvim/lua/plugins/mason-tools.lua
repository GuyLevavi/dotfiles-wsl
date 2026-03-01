-- mason-tools.lua - Mason package management
-- =============================================
-- Defines the canonical list of LSP servers, formatters, linters, and
-- debuggers to install via mason-tool-installer.
--
-- automatic_installation = true means packages in ensure_installed are
-- installed automatically on startup if not already present.

return {
  -- mason-tool-installer: installs all packages in ensure_installed on startup
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
      -- Auto-install any missing packages from ensure_installed on startup
      automatic_installation = true,
    },
  },
}
