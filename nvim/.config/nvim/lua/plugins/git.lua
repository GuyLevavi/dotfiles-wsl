-- git.lua - Git integration plugins
-- ===================================
-- LazyVim already includes lazygit.nvim and gitsigns.nvim.
-- Here we customize them and add diffview.nvim for side-by-side diffs.
--
-- QUICK REFERENCE (LazyVim default keymaps):
--   <leader>gg  Open LazyGit (full-featured git UI)
--   <leader>gf  LazyGit file history
--   <leader>gl  LazyGit log
--   ]h / [h     Jump to next/previous git hunk (changed block)
--   <leader>ghs Stage hunk
--   <leader>ghr Reset hunk
--   <leader>ghp Preview hunk inline

return {
  -- ── Gitsigns: Git Change Indicators ───────────────────────────────
  -- Shows + / ~ / - signs in the gutter (left margin) to indicate
  -- added, modified, or deleted lines. Also provides inline blame.
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      -- Show git blame for the current line as virtual text (dimmed).
      -- This tells you WHO last changed each line and WHEN.
      -- Incredibly useful for understanding why code was written a certain way.
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 500,              -- wait 500ms before showing blame (less jittery)
        virt_text_pos = "eol",    -- show at end of line ("eol" = end of line)
      },
      -- Format: "author name, time ago - commit message"
      current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",

      -- Sign characters in the gutter
      signs = {
        add          = { text = "+" },   -- new lines
        change       = { text = "~" },   -- modified lines
        delete       = { text = "_" },   -- deleted lines (shown on line above)
        topdelete    = { text = "‾" },   -- deleted lines at top of file
        changedelete = { text = "~" },   -- line was changed and lines below deleted
      },
    },
  },

  -- ── Diffview: Side-by-Side Diffs ──────────────────────────────────
  -- Opens a tab with a full side-by-side diff view, like GitHub's
  -- diff viewer but inside Neovim. Great for reviewing changes
  -- before committing.
  --
  -- Commands:
  --   :DiffviewOpen           Open diff of working tree vs HEAD
  --   :DiffviewOpen HEAD~1    Compare with previous commit
  --   :DiffviewOpen main      Compare current branch with main
  --   :DiffviewFileHistory    Browse file history
  --   :DiffviewClose          Close the diff view
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      -- Space+gd: Open diff view (working tree vs last commit)
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      -- Space+gh: Browse the current file's git history
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File git history" },
      -- Space+gH: Browse the entire repo's git history
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Repo git history" },
    },
    opts = {
      -- Use single-column layout (works better in smaller terminals)
      view = {
        default = {
          layout = "diff2_horizontal",
        },
      },
      -- Show file panel on the left
      file_panel = {
        listing_style = "tree",    -- show files as a tree (not flat list)
        win_config = {
          position = "left",
          width = 35,
        },
      },
    },
  },
}
