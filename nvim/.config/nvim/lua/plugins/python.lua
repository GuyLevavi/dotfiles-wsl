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
      -- Find debugpy from Mason installation (with error handling)
      local debugpy_path = nil
      local debugpy_found_in = nil
      
      -- Try Mason registry first (wrapped in pcall for safety)
      local ok, mason_registry = pcall(require, "mason-registry")
      if ok and mason_registry then
        local has_debugpy, _ = pcall(function()
          if mason_registry.is_installed("debugpy") then
            local debugpy_pkg = mason_registry.get_package("debugpy")
            if debugpy_pkg and debugpy_pkg.get_install_path then
              -- Try multiple possible paths
              local possible_paths = {
                debugpy_pkg:get_install_path() .. "/venv/bin/python",
                debugpy_pkg:get_install_path() .. "/bin/python",
                debugpy_pkg:get_install_path() .. "/venv/bin/python3",
                debugpy_pkg:get_install_path() .. "/bin/python3",
              }
              for _, path in ipairs(possible_paths) do
                if vim.fn.executable(path) == 1 then
                  -- Verify it's actually working
                  local test_cmd = path .. " -c \"import debugpy; print(debugpy.__version__)\" 2>/dev/null"
                  local result = vim.fn.system(test_cmd)
                  if vim.v.shell_error == 0 and result ~= "" then
                    debugpy_path = path
                    debugpy_found_in = "Mason"
                    break
                  end
                end
              end
            end
          end
        end)
      end
      
      -- Fallback: check if system Python has debugpy installed
      if not debugpy_path then
        local system_python = vim.fn.exepath("python3") or vim.fn.exepath("python") or "/usr/bin/python3"
        local test_cmd = system_python .. " -m debugpy --version 2>/dev/null"
        local result = vim.fn.system(test_cmd)
        if vim.v.shell_error == 0 then
          debugpy_path = system_python
          debugpy_found_in = "system"
        end
      end
      
      -- Last resort: use any available Python and hope debugpy is importable
      if not debugpy_path then
        local python_path = vim.fn.exepath("python3") or vim.fn.exepath("python") or "/usr/bin/python3"
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if venv then
          local venv_python = venv .. "/bin/python"
          if vim.fn.executable(venv_python) == 1 then
            python_path = venv_python
          end
        end
        debugpy_path = python_path
        debugpy_found_in = "fallback"
      end
      
      -- Setup dap-python with found path
      local dap_python_ok, dap_python = pcall(require, "dap-python")
      if dap_python_ok then
        dap_python.setup(debugpy_path)
        -- Debug notification (only shows if needed)
        -- vim.notify("DAP using " .. debugpy_found_in .. " Python: " .. debugpy_path, vim.log.levels.DEBUG)
      else
        vim.notify("Failed to load dap-python: " .. tostring(dap_python), vim.log.levels.WARN)
      end

      -- Add custom launch configurations
      local dap_ok, dap = pcall(require, "dap")
      if dap_ok and dap.configurations and dap.configurations.python then
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
      end
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
                -- Enable auto-import completions for classes/functions
                autoImportCompletions = true,
                -- Index all installed packages for better completion
                packageIndexDepths = {
                  { name = "sklearn", depth = 2 },
                  { name = "torch", depth = 2 },
                  { name = "cv2", depth = 2 },
                  { name = "numpy", depth = 2 },
                  { name = "pandas", depth = 2 },
                },
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
                autoImportCompletions = true,
              },
            },
          },
        },
      },
    },
  },

  -- ── Disable ruff as LSP to avoid completion conflicts ──────────────
  -- Ruff provides excellent linting but its completion conflicts with
  -- basedpyright's semantic completion. We keep ruff for linting only.
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = vim.tbl_filter(function(source)
        -- Only use ruff for diagnostics/formatting, not completion
        return not source.name:match("ruff")
      end, opts.sources or {})
    end,
  },
}
