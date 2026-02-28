-- mason-tools.lua - Pre-install Mason packages for airgap
-- =========================================================
-- All tools needed for the development environment.
-- mason-tool-installer.nvim will install these on first run.
--
-- IMPORTANT: We explicitly EXCLUDE packages that LazyVim extras
-- auto-install but we don't need:
--   - pyright (we use basedpyright)
--   - docker-compose-language-service (we don't need docker-compose LSP)
--   - lua-language-server (not needed for our use case)
--   - marksman (markdown LSP, not needed)

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
      -- Disable automatic installation of LSP servers from lspconfig
      -- We explicitly control what gets installed above
      automatic_installation = false,
    },
  },

  -- Override LazyVim's Mason auto-install to exclude unwanted packages
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      -- Only install servers we explicitly want, don't auto-install
      automatic_installation = {
        exclude = {
          "pyright", -- We use basedpyright
          "docker_compose_language_service", -- Not needed
          "lua_ls", -- Lua language server not needed
          "marksman", -- Markdown LSP not needed
        },
      },
    },
  },
}
