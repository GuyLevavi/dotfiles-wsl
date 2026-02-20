-- editor.lua - Editor enhancement plugins
-- =========================================
-- These plugins improve the core editing experience: finding files,
-- searching text, viewing diagnostics, and navigating code.
-- Most are already included in LazyVim — we just customize them here.

return {
  -- ── Telescope: Fuzzy Finder ───────────────────────────────────────
  -- Telescope is the "find anything" tool. It uses fuzzy matching,
  -- so you don't need to type exact names.
  --
  -- ESSENTIAL KEYMAPS (memorize these!):
  --   <leader><space>  Find files (by name)
  --   <leader>ff       Find files (same as above)
  --   <leader>fg       Live grep (search file CONTENTS)
  --   <leader>fb       Find open buffers (switch between files)
  --   <leader>fr       Find recent files
  --   <leader>fs       Find symbols (functions, classes in current file)
  --   <leader>/        Grep in current buffer
  --
  -- INSIDE TELESCOPE:
  --   <C-j>/<C-k>      Move up/down in results
  --   <CR>              Open selected file
  --   <C-x>             Open in horizontal split
  --   <C-v>             Open in vertical split
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        -- Layout: show preview on the right side (great for seeing file contents)
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = {
            preview_width = 0.55,  -- preview takes 55% of telescope window
            prompt_position = "top", -- search bar at top (feels more natural)
          },
          width = 0.87,             -- telescope window takes 87% of screen
          height = 0.80,            -- and 80% of height
        },
        sorting_strategy = "ascending", -- best match at top (near the prompt)

        -- Files and directories to ignore in search results.
        -- These are common in ML/CV projects and would just add noise.
        file_ignore_patterns = {
          "%.pyc",                  -- compiled Python bytecode
          "__pycache__/",           -- Python cache directories
          "%.egg%-info/",           -- Python package metadata
          "node_modules/",          -- JavaScript dependencies (if any)
          "%.git/",                 -- git internals
          "%.venv/",               -- virtual environments
          "venv/",
          "%.mypy_cache/",         -- mypy type checker cache
          "%.ruff_cache/",         -- ruff linter cache
          "%.pytest_cache/",       -- pytest cache
          "wandb/",                -- Weights & Biases experiment logs
          "mlruns/",               -- MLflow experiment logs
          "outputs/",              -- Hydra/training outputs
          "checkpoints/",          -- model checkpoints (can be huge)
          "%.onnx",                -- ONNX model files
          "%.pt",                  -- PyTorch model files
          "%.pth",                 -- PyTorch model files
          "%.h5",                  -- HDF5/Keras model files
        },
      },
    },
    keys = {
      -- Add a keymap to search for Python symbols specifically
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

  -- ── Which-Key: Keymap Discovery ───────────────────────────────────
  -- Which-key shows a popup of available keymaps when you press a prefix.
  -- Press <leader> and wait — you'll see ALL keymaps organized by category.
  -- This is THE tool for learning Neovim keymaps as a beginner.
  --
  -- We add custom group labels so our Python/REPL keymaps show up nicely.
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        -- Define labels for our custom keymap groups.
        -- These show up in the which-key popup as category headers.
        { "<leader>r", group = "run/REPL", icon = "" },   -- our Python run keymaps
        { "<leader>d", group = "debug", icon = "" },       -- debug keymaps
        { "<leader>t", group = "test", icon = "" },        -- test keymaps
        { "<leader>g", group = "git", icon = "" },         -- git keymaps
      },
    },
  },

  -- ── Todo Comments: Highlight TODO/FIXME/HACK ─────────────────────
  -- Highlights special comments in your code with bright colors:
  --   TODO:   something to do later (highlighted in blue)
  --   FIXME:  something broken that needs fixing (highlighted in red)
  --   HACK:   a workaround that should be improved (highlighted in orange)
  --   NOTE:   important information (highlighted in green)
  --   PERF:   performance-related note (highlighted in purple)
  --
  -- Press <leader>st to search all TODOs in the project.
  -- Press ]t / [t to jump between TODO comments.
  -- Already included in LazyVim, we just ensure it's configured.
  {
    "folke/todo-comments.nvim",
    opts = {
      -- Highlight the keyword and the text after it
      highlight = {
        multiline = false,    -- only highlight the TODO line, not following lines
        pattern = [[.*<(KEYWORDS)\s*:]],  -- pattern to match: "TODO:", "FIXME:", etc.
      },
    },
  },

  -- ── Trouble: Better Diagnostics List ──────────────────────────────
  -- Trouble shows all errors, warnings, and other diagnostics in a
  -- clean, organized panel at the bottom of the screen.
  -- Much better than scrolling through your code looking for red squiggles.
  --
  -- KEYMAPS (LazyVim defaults):
  --   <leader>xx  Toggle diagnostics panel
  --   <leader>xX  Buffer diagnostics (current file only)
  --   <leader>xL  Location list
  --   <leader>xQ  Quickfix list
  -- Already included in LazyVim with good defaults.
  {
    "folke/trouble.nvim",
    opts = {
      -- Use icons to indicate severity (makes it easier to scan)
      use_diagnostic_signs = true,
    },
  },

  -- ── Indent Blankline: Show Indentation Guides ─────────────────────
  -- Draws vertical lines at each indentation level.
  -- Incredibly helpful in Python where indentation IS the syntax.
  -- You can immediately see which block of code belongs to which
  -- function, class, if-statement, or loop.
  -- Already in LazyVim, just ensure scope highlighting is on.
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",  -- v3 uses "ibl" as the module entry point (not "indent_blankline")
    opts = {
      scope = {
        -- Highlight the current indentation scope (the block you're in)
        -- This draws a brighter line around the current function/class/loop.
        enabled = true,
        show_start = true,    -- highlight the first line of the scope
      },
    },
  },
}
