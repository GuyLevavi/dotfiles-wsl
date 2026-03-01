-- editor.lua - Editor enhancement plugins
-- =========================================
-- Customizations on top of LazyVim defaults for Python/CV/ML work.

return {
  -- ── Snacks Picker: Symbol Search ─────────────────────────────────
  -- LazyVim (install_version >= 8) uses snacks.picker as the default picker.
  -- Add <leader>sP to search Classes/Functions/Methods in the current file.
  -- (LazyVim already provides <leader>ss for all symbol kinds via snacks.)
  --
  -- basedpyright supports documentSymbol but NOT workspace/symbol,
  -- so <leader>sS (workspace symbols) will gracefully show nothing.
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>sP",
        function()
          Snacks.picker.lsp_symbols({
            -- filter must be keyed by filetype (or "default").
            -- A flat list { "Class", ... } doesn't work — the picker
            -- indexes by filetype string, not by integer.
            filter = { default = { "Class", "Function", "Method" } },
          })
        end,
        desc = "Python symbols (Class/Function/Method)",
      },
    },
  },

  -- ── Telescope: File-ignore Patterns ──────────────────────────────
  -- telescope.nvim is still installed (used by some plugins) but snacks
  -- is the active picker. We keep file_ignore_patterns to suppress ML
  -- noise if telescope is invoked directly.
  --
  -- ESSENTIAL KEYMAPS (snacks defaults):
  --   <leader><space>  Find files     <leader>/   Grep
  --   <leader>fb       Buffers        <leader>fr  Recent files
  --   <leader>ss       LSP symbols    <leader>sP  Python symbols (above)
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

