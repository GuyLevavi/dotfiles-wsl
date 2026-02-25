-- mason-tool-installer.lua - Automatic LSP/DAP/formatter/linter installation
-- ================================================================
-- mason-tool-installer.nvim ensures all Mason packages are installed
-- automatically. This is critical for airgap environments where we
-- pre-install everything.
--
-- Usage: :MasonToolsInstallSync (installs all declared tools)
--        :MasonToolsUpdateSync (updates to latest)

return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    cmd = { "MasonToolsInstallSync", "MasonToolsUpdateSync" },
    opts = {
      -- Run automatically on startup (disabled for airgap - we pre-install)
      auto_update = false,
      run_on_start = false,
      -- These tools will be installed by MasonToolsInstallSync
      ensure_installed = {
        -- Python LSP/format/lint
        "pyright",
        "ruff",
        "debugpy",
        -- Lua
        "lua-language-server",
        "stylua",
        -- Shell
        "bash-language-server",
        "shfmt",
        -- JSON/YAML
        "json-lsp",
        "yaml-language-server",
        -- Docker
        "dockerfile-language-server",
        -- Other
        "markdown-oxide",
      },
    },
  },
}
