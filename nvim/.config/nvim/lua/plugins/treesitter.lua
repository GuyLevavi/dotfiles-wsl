-- treesitter.lua - Syntax highlighting and code understanding
-- =============================================================
-- LazyVim already enables highlight, indent, and incremental_selection
-- with the same keymaps (<C-space> to expand, <bs> to shrink).
-- Here we just specify which parsers to pre-install and add text objects.

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      -- Auto-install parsers for any filetype that lacks one
      auto_install = true,
      ignore_install = {},
      ensure_installed = {
        -- Primary
        "python",
        "lua",
        -- Shell & DevOps
        "bash",
        "dockerfile",
        -- Data formats
        "json",
        "yaml",
        "toml",
        -- Documentation
        "markdown",
        "markdown_inline",
        -- Vim
        "vim",
        "vimdoc",
        -- Utility
        "regex",
        "gitcommit",
        "gitignore",
        "git_rebase",
        "diff",
        "helm",
        "requirements",
        -- Web (ML dashboards)
        "html",
        "css",
      },
      -- Disable treesitter for very large files (>100KB) to prevent slowdown.
      highlight = {
        disable = function(_, buf)
          local max_filesize = 100 * 1024
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end
        end,
      },
    },
  },

  -- ── Treesitter Text Objects ───────────────────────────────────────
  -- Operate on code structures with vim motions:
  --   vaf/vif  select around/inside function
  --   vac/vic  select around/inside class
  --   vaa/via  select around/inside argument
  --   <leader>a / <leader>A  swap arguments
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    opts = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = { query = "@function.outer", desc = "Select around function" },
          ["if"] = { query = "@function.inner", desc = "Select inside function" },
          ["ac"] = { query = "@class.outer", desc = "Select around class" },
          ["ic"] = { query = "@class.inner", desc = "Select inside class" },
          ["aa"] = { query = "@parameter.outer", desc = "Select around argument" },
          ["ia"] = { query = "@parameter.inner", desc = "Select inside argument" },
          ["al"] = { query = "@loop.outer", desc = "Select around loop" },
          ["il"] = { query = "@loop.inner", desc = "Select inside loop" },
          ["ai"] = { query = "@conditional.outer", desc = "Select around if" },
          ["ii"] = { query = "@conditional.inner", desc = "Select inside if" },
        },
      },
      swap = {
        enable = true,
        swap_next = {
          ["<leader>a"] = { query = "@parameter.inner", desc = "Swap with next argument" },
        },
        swap_previous = {
          ["<leader>A"] = { query = "@parameter.inner", desc = "Swap with prev argument" },
        },
      },
    },
  },
}
