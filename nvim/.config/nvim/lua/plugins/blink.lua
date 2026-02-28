-- blink.lua - Completion engine configuration (replaces nvim-cmp)
-- ==================================================================
-- blink.cmp is LazyVim's modern completion engine.
-- By default it shows LSP, path, snippets, and buffer completions.
-- For Python ML work, we want clean LSP-based completions only.
--
-- Common issue: "bad LLM completions" = buffer completions showing
-- random words from the current file mixed with proper LSP suggestions.
--
-- AIRGAP NOTE: This plugin is pinned to prevent network access on toggle.
-- Use `pin = true` to prevent Lazy from checking for updates.

return {
  {
    "saghen/blink.cmp",
    -- PINNED for airgap: prevents Lazy from checking GitHub for updates
    pin = true,
    -- Explicitly set directory to ensure offline availability
    dir = vim.fn.stdpath("data") .. "/lazy/blink.cmp",
    opts = {
      -- ── Completion Sources ────────────────────────────────────────────
      -- Order matters: first match wins
      -- We DISABLE buffer (word) completions entirely to avoid "bad LLM"
      -- looking suggestions that are just random words from the file.
      sources = {
        default = { "lsp", "path", "snippets" },
        -- Explicitly exclude buffer completions
        providers = {
          buffer = { enabled = false },
          lsp = {
            score_offset = 10, -- Prioritize LSP heavily
          },
          path = {
            score_offset = 5, -- Lower priority than LSP
            -- Only complete absolute/relative paths, not every word
            opts = {
              trailing_slash = false,
              label_trailing_slash = true,
            },
          },
          snippets = {
            score_offset = 3, -- Lowest priority
          },
        },
      },

      -- ── Fuzzy Matching ────────────────────────────────────────────────
      -- Use smart fuzzy matching for better completion quality
      fuzzy = {
        -- Prefer exact matches and prefix matches
        sorts = { "exact", "score", "sort_text" },
      },

      -- ── Keymaps ──────────────────────────────────────────────────────
      -- Keep default LazyVim keymaps (CR to accept, Tab to select next, etc.)
      keymap = {
        preset = "enter",
        -- Disable Tab for snippets when completion menu is open
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },

      -- ── Appearance ───────────────────────────────────────────────────
      -- Show only high-quality completions, filter out low-confidence items
      completion = {
        -- Don't auto-insert text before confirming
        accept = {
          auto_brackets = {
            enabled = true, -- Auto-add () for functions
          },
        },
        -- Menu appearance
        menu = {
          -- Limit number of items to reduce noise
          max_height = 10,
          -- Show source name (LSP, path, etc.)
          draw = {
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
        },
        -- Documentation popup (shows docstrings)
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        -- Ghost text (preview of completion)
        ghost_text = {
          enabled = false, -- Disabled: can be distracting
        },
      },
    },
  },
}
