-- editor.lua - Editor enhancement plugins
-- =========================================
-- Customizations on top of LazyVim defaults for Python/CV/ML work.

return {
  -- ── Telescope: Fuzzy Finder ───────────────────────────────────────
  -- ESSENTIAL KEYMAPS:
  --   <leader><space>  Find files     <leader>fg  Live grep
  --   <leader>fb       Find buffers   <leader>fr  Recent files
  --   <leader>fs       Find symbols   <leader>/   Grep in buffer
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = {
            preview_width = 0.55,
            prompt_position = "top",
          },
          width = 0.87,
          height = 0.80,
        },
        sorting_strategy = "ascending",

        -- Ignore ML/Python noise in search results
        file_ignore_patterns = {
          "%.pyc",
          "__pycache__/",
          "%.egg%-info/",
          "node_modules/",
          "%.git/",
          "%.venv/",
          "venv/",
          "%.mypy_cache/",
          "%.ruff_cache/",
          "%.pytest_cache/",
          "wandb/",
          "mlruns/",
          "outputs/",
          "checkpoints/",
          "%.onnx",
          "%.pt",
          "%.pth",
          "%.h5",
        },
      },
    },
    keys = {
      {
        "<leader>sP",
        function()
          require("telescope.builtin").lsp_dynamic_workspace_symbols({
            symbols = { "Class", "Function", "Method" },
          })
        end,
        desc = "Search Python symbols (classes/functions)",
      },
    },
  },

  -- ── Which-Key: Custom Group Labels ────────────────────────────────
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>r", group = "run/REPL", icon = "" },
        { "<leader>d", group = "debug", icon = "" },
        { "<leader>t", group = "test", icon = "" },
        { "<leader>g", group = "git", icon = "" },
      },
    },
  },

  -- ── Todo Comments ────────────────────────────────────────────────
  -- Highlights TODO/FIXME/HACK/NOTE in code. Press <leader>st to search.
  {
    "folke/todo-comments.nvim",
    opts = {
      highlight = {
        multiline = false,
      },
    },
  },
}
