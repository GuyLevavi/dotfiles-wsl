-- jupyter.lua - REPL / Interactive Python development
-- =====================================================
-- For Computer Vision and Deep Learning work, you often want to
-- send code to a Python REPL interactively (like Jupyter, but in the terminal).
--
-- We use iron.nvim which lets you:
--   1. Open a Python REPL inside Neovim
--   2. Send lines or visual selections to the REPL
--   3. See output immediately
--
-- This is great for:
--   - Exploring data (images, tensors, dataframes)
--   - Testing small code snippets
--   - Debugging model outputs interactively
--
-- WORKFLOW:
--   1. Open a Python file
--   2. Press <leader>rs to start the REPL (opens in a split)
--   3. Select code in visual mode, press <leader>rs to send it
--   4. Press <leader>rl to send the current line
--   5. The output appears in the REPL split

return {
  -- ── Iron.nvim: Interactive REPL ───────────────────────────────────
  {
    "Vigemus/iron.nvim",
    keys = {
      -- Only load iron.nvim when these keymaps are pressed (lazy loading)
      { "<leader>rs", desc = "REPL: Send / Start" },
      { "<leader>rl", desc = "REPL: Send line" },
      { "<leader>rf", desc = "REPL: Send file" },
      { "<leader>rc", desc = "REPL: Clear" },
      { "<leader>rq", desc = "REPL: Quit" },
    },
    config = function()
      local iron = require("iron.core")
      local view = require("iron.view")

      iron.setup({
        config = {
          -- Define which REPL to use for each filetype
          repl_definition = {
            python = {
              -- Try ipython first (better for ML work: auto-reload, magic commands)
              -- Falls back to regular python3 if ipython is not installed
              command = function()
                if vim.fn.executable("ipython3") == 1 then
                  -- --no-autoindent prevents ipython from adding extra indentation
                  -- when pasting multi-line code blocks
                  return { "ipython3", "--no-autoindent" }
                elseif vim.fn.executable("ipython") == 1 then
                  return { "ipython", "--no-autoindent" }
                else
                  return { "python3" }
                end
              end,
            },
          },
          -- Open the REPL in a vertical split on the right, taking 40% of width
          repl_open_cmd = view.split.vertical.botright(0.4),
          -- Don't close the REPL when the source buffer is closed
          close_window_on_exit = false,
        },

        -- Highlight sent code briefly so you can see what was sent
        highlight = {
          italic = true,
        },

        -- Ignore blank lines when sending to REPL (cleaner output)
        ignore_blank_lines = true,
      })

      -- ── REPL Keymaps ────────────────────────────────────────────────
      local map = vim.keymap.set

      -- Visual mode: send selected text to REPL
      -- Usage: Select lines with V, then press <leader>rs
      map("v", "<leader>rs", function()
        iron.visual_send()
      end, { desc = "REPL: Send selection" })

      -- Normal mode: start/toggle the REPL
      map("n", "<leader>rs", function()
        iron.repl_for("python")
      end, { desc = "REPL: Start/focus Python REPL" })

      -- Send the current line to the REPL
      map("n", "<leader>rl", function()
        iron.send_line()
      end, { desc = "REPL: Send current line" })

      -- Send the entire file to the REPL
      map("n", "<leader>rf", function()
        iron.send_file()
      end, { desc = "REPL: Send entire file" })

      -- Clear the REPL screen
      map("n", "<leader>rc", function()
        iron.send(nil, string.char(12)) -- Ctrl+L (clear screen)
      end, { desc = "REPL: Clear screen" })

      -- Close/quit the REPL
      map("n", "<leader>rq", function()
        iron.close_repl("python")
      end, { desc = "REPL: Quit" })

      -- Send a "paragraph" (code block) — from current line to next blank line
      map("n", "<leader>rp", function()
        iron.send_paragraph()
      end, { desc = "REPL: Send paragraph/block" })
    end,
  },
}
