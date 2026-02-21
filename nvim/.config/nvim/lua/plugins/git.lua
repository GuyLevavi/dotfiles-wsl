-- git.lua - Git integration plugins
-- ===================================
-- LazyVim includes lazygit.nvim and gitsigns.nvim by default.
-- We customize gitsigns and add diffview.nvim for side-by-side diffs.
--
-- QUICK REFERENCE (LazyVim defaults):
--   <leader>gg  Open LazyGit       ]h / [h      Next/prev hunk
--   <leader>gf  LazyGit file       <leader>ghs  Stage hunk
--   <leader>gl  LazyGit log        <leader>ghr  Reset hunk

return {
  -- ── Gitsigns: Inline Blame + Custom Signs ─────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 500,
        virt_text_pos = "eol",
      },
      current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
      signs = {
        add          = { text = "+" },
        change       = { text = "~" },
        delete       = { text = "_" },
        topdelete    = { text = "‾" },
        changedelete = { text = "~" },
      },
    },
  },

  -- ── Diffview: Side-by-Side Diffs ──────────────────────────────────
  --   :DiffviewOpen         diff working tree vs HEAD
  --   :DiffviewOpen HEAD~1  compare with previous commit
  --   :DiffviewFileHistory  browse file/repo history
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File git history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Repo git history" },
    },
    opts = {
      view = {
        default = { layout = "diff2_horizontal" },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 35 },
      },
    },
  },
}
