-- python.lua - Python-specific plugin configuration
-- ===================================================
-- Customizations on top of the LazyVim Python extra (lang.python)
-- and DAP core extra (dap.core). Those extras already handle:
--   - basedpyright (type checking / intellisense) - primary
--   - ruff (linting via LSP)
--   - nvim-dap + dap-ui + virtual-text + mason-nvim-dap
--   - nvim-dap-python (setup + <leader>dPt / <leader>dPc)
--   - neotest-python (adapter registration)
--   - venv-selector.nvim
--   - All <leader>d* debug keymaps
--
-- Here we ONLY add things the extras don't provide:
--   - F-key debug shortcuts (VS Code style)
--   - Custom debug configurations (launch with args, launch module)
--   - Neotest pytest args (-v -s)
--   - Conform ruff formatter setup
--   - basedpyright as primary LSP (pyright as fallback)

-- Use basedpyright as primary Python LSP (pyright as fallback)
vim.g.lazyvim_python_lsp = "basedpyright"

return {
  -- ── VS Code-style Debug Keymaps (F-keys) ─────────────────────────
  -- The DAP core extra uses <leader>d* keymaps. These F-key bindings
  -- are more intuitive if you're coming from VS Code / PyCharm.
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "Debug: Continue / Start" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "Debug: Step Out" },
    },
  },

  -- ── Custom Debug Configurations ──────────────────────────────────
  -- Additional launch configs beyond the defaults from dap-python.
  -- These cover common Python/ML scenarios.
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    config = function()
      -- Use the active venv's Python instead of mason's debugpy-adapter.
      -- This ensures debugpy runs in the same env as your project.
      local python_path = vim.fn.exepath("python3") or vim.fn.exepath("python") or "python3"
      local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
      if venv then
        local venv_python = venv .. "/bin/python"
        if vim.fn.executable(venv_python) == 1 then
          python_path = venv_python
        end
      end
      require("dap-python").setup(python_path)

      -- Add custom launch configurations
      local dap = require("dap")
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch file with arguments",
        program = "${file}",
        args = function()
          local input = vim.fn.input("Arguments: ")
          return vim.split(input, " ", { trimempty = true })
        end,
      })
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch module (-m)",
        module = function()
          return vim.fn.input("Module name: ")
        end,
      })
    end,
  },

  -- ── Neotest: Custom pytest args ──────────────────────────────────
  -- The extra registers the adapter but doesn't set args or runner.
  -- We add -v (verbose) and -s (no stdout capture) for better output.
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
          args = { "-v", "-s" },
          python = function()
            local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
            if venv then
              return venv .. "/bin/python"
            end
            return vim.fn.exepath("python3") or "python3"
          end,
        },
      },
    },
  },

  -- ── Ruff Formatter (conform.nvim) ────────────────────────────────
  -- The Python extra sets up ruff as an LSP linter but does NOT
  -- configure conform.nvim for formatting. We add that here.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_format" },
      },
    },
  },

  -- ── basedpyright: ML-friendly settings ─────────────────────────────
  -- "basic" type checking is less noisy for ML code where libraries
  -- like torch, cv2, numpy often have incomplete type stubs.
  -- basedpyright is the primary LSP (set above via vim.g.lazyvim_python_lsp)
  -- pyright is configured as a fallback if basedpyright is not available.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        },
      },
    },
  },
}
