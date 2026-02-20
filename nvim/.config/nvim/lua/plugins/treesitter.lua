-- treesitter.lua - Syntax highlighting and code understanding
-- =============================================================
-- Treesitter parses your code into an AST (Abstract Syntax Tree)
-- and uses it for:
--   1. Accurate syntax highlighting (much better than regex-based)
--   2. Smart indentation
--   3. Code folding
--   4. Incremental selection (expand selection by scope)
--   5. Text objects (select inside function, class, etc.)
--
-- USEFUL KEYMAPS (from LazyVim):
--   <C-space>   Start incremental selection, press again to expand
--               (e.g., selects variable → expression → statement → function)
--   <bs>        Shrink the selection back down (backspace in visual mode)
--
-- Each "parser" is a language grammar. Treesitter downloads and compiles
-- them automatically. We list all the languages we want pre-installed.

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- ── Primary Languages ──────────────────────────────────────
        "python",       -- our main language (CV / Deep Learning)
        "lua",          -- Neovim config language (this file!)

        -- ── Shell & DevOps ─────────────────────────────────────────
        "bash",         -- shell scripts, Dockerfiles' RUN commands
        "dockerfile",   -- Dockerfile syntax highlighting

        -- ── Data Formats ───────────────────────────────────────────
        "json",         -- config files, API responses, COCO annotations
        "jsonc",        -- JSON with comments (VS Code settings, etc.)
        "yaml",         -- docker-compose, GitHub Actions, config files
        "toml",         -- pyproject.toml, Poetry/uv config files

        -- ── Documentation ──────────────────────────────────────────
        "markdown",     -- README files, documentation
        "markdown_inline", -- inline markdown (code blocks, etc.)

        -- ── Vim ────────────────────────────────────────────────────
        "vim",          -- vim script (legacy config files)
        "vimdoc",       -- vim help documentation (`:help` pages)

        -- ── Utility ────────────────────────────────────────────────
        "regex",        -- regular expressions (highlighted in code)
        "gitcommit",    -- git commit messages
        "gitignore",    -- .gitignore file syntax
        "git_rebase",   -- git rebase interactive mode
        "diff",         -- diff/patch file format
        "helm",         -- Helm chart templates (Kubernetes)
        "requirements", -- requirements.txt syntax

        -- ── Web (optional, but common in ML dashboards) ────────────
        "html",         -- HTML templates
        "css",          -- stylesheets
      },

      -- ── Syntax Highlighting ──────────────────────────────────────
      highlight = {
        enable = true,    -- enable treesitter-based highlighting
        -- Disable for very large files (>100KB) to prevent slowdown.
        -- This is relevant for ML where you might open large data files.
        disable = function(_, buf)
          local max_filesize = 100 * 1024 -- 100 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end
        end,
      },

      -- ── Indentation ──────────────────────────────────────────────
      -- Use treesitter for auto-indentation. This is more accurate
      -- than Neovim's built-in indentation, especially for Python
      -- where indentation defines code structure.
      indent = {
        enable = true,
      },

      -- ── Incremental Selection ────────────────────────────────────
      -- Press Ctrl+Space to start selecting, then press again to expand
      -- the selection to the next larger syntax node. Very useful!
      -- Example in Python:
      --   1st press: select variable name
      --   2nd press: select full expression
      --   3rd press: select statement
      --   4th press: select function body
      --   5th press: select entire function
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",     -- start selection
          node_incremental = "<C-space>",   -- expand to larger node
          scope_incremental = false,        -- disabled (less useful)
          node_decremental = "<bs>",        -- shrink selection (backspace)
        },
      },
    },
  },

  -- ── Treesitter Text Objects ───────────────────────────────────────
  -- Text objects let you operate on code structures with vim motions.
  -- For example:
  --   vaf  = select around function (visual mode, around, function)
  --   vif  = select inside function
  --   vac  = select around class
  --   vic  = select inside class
  --   daf  = delete a function
  --   cif  = change inside function (delete and enter insert mode)
  --   ]f   = jump to next function start  (LazyVim default)
  --   [f   = jump to previous function start
  --   ]c   = jump to next class start
  --   [c   = jump to previous class start
  --
  -- This is incredibly powerful for refactoring Python code!
  --
  -- NOTE: LazyVim already configures move keymaps (]f, ]c, ]a, etc.)
  -- in its treesitter.lua. We extend those defaults with select and
  -- swap keymaps here. The `opts` table is deep-merged with LazyVim's.
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    opts = {
      select = {
        enable = true,
        lookahead = true,    -- jump forward to matching text object
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
