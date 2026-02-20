-- python.lua - Python-specific plugin configuration
-- ===================================================
-- This file configures debugging, testing, and formatting tools
-- specifically for Python / Computer Vision / Deep Learning work.
--
-- The LazyVim Python extra (enabled in lazy.lua) already sets up:
--   - pyright (type checking / intellisense)
--   - ruff (linting + formatting, replaces flake8/black/isort)
-- Here we add debugging, testing, and fine-tune those tools.

return {
  -- ── Python Debugging with debugpy ─────────────────────────────────
  -- nvim-dap is the Debug Adapter Protocol client (like VS Code's debugger).
  -- nvim-dap-python adds Python-specific debug configurations.
  --
  -- PREREQUISITE: Install debugpy in your environment:
  --   pip install debugpy
  --   # or with uv:
  --   uv pip install debugpy
  {
    "mfussenegger/nvim-dap-python",
    -- Only load this plugin when we open a Python file
    ft = "python",
    dependencies = {
      "mfussenegger/nvim-dap",    -- the core DAP client
      "rcarriga/nvim-dap-ui",     -- pretty debugger UI (panels, watches, etc.)
    },
    config = function()
      -- Try to find the Python executable.
      -- Priority: active virtual env > uv-managed python > system python3
      local python_path = vim.fn.exepath("python3") or vim.fn.exepath("python") or "python3"

      -- Check if we're in a virtual environment (common with uv, venv, conda)
      local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
      if venv then
        -- Use the Python from the active virtual environment
        local sep = vim.fn.has("win32") == 1 and "\\" or "/"
        local venv_python = venv .. sep .. (vim.fn.has("win32") == 1 and "Scripts" or "bin") .. sep .. "python"
        if vim.fn.executable(venv_python) == 1 then
          python_path = venv_python
        end
      end

      require("dap-python").setup(python_path)

      -- ── Debug Keymaps ───────────────────────────────────────────────
      -- These mimic VS Code's debug shortcuts, which you may already know.
      local dap = require("dap")
      local map = vim.keymap.set

      -- F5: Start or continue debugging (like pressing Play)
      map("n", "<F5>", dap.continue, { desc = "Debug: Continue / Start" })

      -- F10: Step Over (run the current line, don't go into functions)
      map("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })

      -- F11: Step Into (go inside the function on the current line)
      map("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })

      -- Shift+F11: Step Out (finish the current function, go back to caller)
      map("n", "<S-F11>", dap.step_out, { desc = "Debug: Step Out" })

      -- Space+db: Toggle a breakpoint on the current line
      -- (LazyVim's DAP extra may already set this, but explicit is better)
      map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })

      -- Space+dB: Set a conditional breakpoint (prompts for condition)
      -- e.g., "i > 100" will only stop when i is greater than 100
      map("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Debug: Conditional Breakpoint" })

      -- Space+dr: Open the debug REPL (interactive debugger console)
      map("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })

      -- ── Custom Debug Configurations ─────────────────────────────────
      -- These cover common Python/ML scenarios beyond the defaults.
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch file with arguments",
        program = "${file}",
        args = function()
          -- Prompt for command-line arguments (useful for training scripts)
          -- e.g., "--epochs 10 --lr 0.001 --batch-size 32"
          local input = vim.fn.input("Arguments: ")
          return vim.split(input, " ", { trimempty = true })
        end,
      })

      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch module (-m)",
        module = function()
          -- Run as `python -m module_name` (common for packages)
          return vim.fn.input("Module name: ")
        end,
      })
    end,
  },

  -- ── Neotest: Test Runner ──────────────────────────────────────────
  -- Neotest provides a unified interface for running tests.
  -- neotest-python adds pytest support.
  -- You can run individual tests, files, or the full suite.
  --
  -- Key bindings (set by LazyVim's DAP extra):
  --   <leader>tt  Run nearest test
  --   <leader>tT  Run current file's tests
  --   <leader>ts  Show test summary panel
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
    },
    opts = {
      adapters = {
        ["neotest-python"] = {
          -- Use pytest as the test runner (not unittest)
          runner = "pytest",
          -- Pass useful flags to pytest:
          --   -v: verbose output (show individual test names)
          --   -s: don't capture stdout (so print() works in tests)
          args = { "-v", "-s" },
          -- Auto-detect the Python from virtual environments
          python = function()
            local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
            if venv then
              local sep = vim.fn.has("win32") == 1 and "\\" or "/"
              return venv .. sep .. (vim.fn.has("win32") == 1 and "Scripts" or "bin") .. sep .. "python"
            end
            return vim.fn.exepath("python3") or "python3"
          end,
        },
      },
    },
  },

  -- ── Ruff: Linter + Formatter ──────────────────────────────────────
  -- Ruff replaces flake8, black, isort, pycodestyle, and more.
  -- It's written in Rust and is 10-100x faster than the Python tools.
  -- The LazyVim Python extra already configures ruff-lsp, but here
  -- we ensure conform.nvim uses ruff for formatting too.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- Use ruff for both import sorting and code formatting.
        -- This runs ruff's isort-equivalent first, then its formatter.
        python = { "ruff_organize_imports", "ruff_format" },
      },
    },
  },

  -- ── Pyright Configuration ─────────────────────────────────────────
  -- Pyright is a fast Python type checker (like mypy but faster).
  -- Here we tweak its settings to be less noisy for ML code,
  -- where type annotations are often missing from libraries like
  -- torch, cv2, numpy, etc.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            python = {
              analysis = {
                -- "basic" is less strict than "standard" or "strict".
                -- ML libraries often have incomplete type stubs, so
                -- strict mode would produce too many false positives.
                typeCheckingMode = "basic",
                -- Auto-detect import paths from the virtual environment
                autoSearchPaths = true,
                -- Use library stubs for better completions
                useLibraryCodeForTypes = true,
                -- Diagnose missing imports (very helpful to catch typos)
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        },
      },
    },
  },
}
