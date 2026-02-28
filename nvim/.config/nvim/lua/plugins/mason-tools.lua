-- mason-tools.lua - Pre-install Mason packages for airgap
-- =========================================================
-- All tools needed for the development environment.
-- mason-tool-installer.nvim will install these on first run.

return {
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
        -- Markdown
        "markdownlint-cli2",
        "markdown-toc",
        -- Already installed but list for verification
        "shfmt",
        "stylua",
        "hadolint",
        "tree-sitter-cli",
      },
    },
  },
}
