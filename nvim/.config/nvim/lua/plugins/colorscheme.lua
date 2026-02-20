-- colorscheme.lua - Theme / color scheme configuration
-- =====================================================
-- Catppuccin Mocha is a warm, dark theme with excellent contrast.
-- It has first-class support for Neovim and most plugins (treesitter,
-- telescope, gitsigns, etc.), so everything looks consistent.
--
-- Other popular options you might try:
--   "catppuccin-latte" (light theme)
--   "catppuccin-frappe" (medium dark)
--   "catppuccin-macchiato" (darker)
--   "tokyonight" (LazyVim default)
--   "gruvbox" (warm retro feel)
--
-- COLORBLIND SUPPORT:
--   nightfox.nvim has built-in daltonization (color vision deficiency simulation).
--   It shifts red-green colors to blue-orange so diffs, diagnostics, and git
--   signs are distinguishable with deuteranopia or protanopia.
--   To switch: uncomment the nightfox block below and change the LazyVim
--   colorscheme at the bottom to "nightfox" (or carbonfox, nordfox, etc.).
--   Also switch WezTerm to the matching scheme in .wezterm.lua.

return {
	-- ── Catppuccin (active) ─────────────────────────────────────────────
	-- {
	-- 	"catppuccin/nvim",
	-- 	name = "catppuccin", -- use "catppuccin" as the plugin name
	-- 	priority = 1000, -- load before other plugins (so UI renders correctly)
	-- 	opts = {
	-- 		flavour = "mocha", -- darkest variant; easy on the eyes
	-- 		integrations = {
	-- 			-- Enable theme integration with plugins we use.
	-- 			-- This makes gitsigns, telescope, treesitter, etc. use
	-- 			-- Catppuccin's color palette for a unified look.
	-- 			cmp = true, -- nvim-cmp (autocompletion menu)
	-- 			gitsigns = true, -- git change indicators in the gutter
	-- 			telescope = { enabled = true },
	-- 			treesitter = true, -- syntax highlighting
	-- 			mini = { enabled = true },
	-- 			native_lsp = {
	-- 				enabled = true,
	-- 				virtual_text = {
	-- 					errors = { "italic" },
	-- 					hints = { "italic" },
	-- 					warnings = { "italic" },
	-- 					information = { "italic" },
	-- 				},
	-- 			},
	-- 			dap = true, -- debugger UI
	-- 			dap_ui = true, -- debugger UI panels
	-- 			which_key = true, -- keymap popup
	-- 			neotest = true, -- test runner
	-- 			notify = true, -- notification popups
	-- 			noice = true, -- enhanced UI
	-- 		},
	-- 	},
	-- },

	-- ── Nightfox (colorblind-friendly alternative) ────────────────────
	-- Uncomment this block to use nightfox with daltonization.
	-- The colorblind option shifts the entire palette so red-green
	-- differences become blue-orange — similar to PyCharm's colorblind mode.
	--
	-- Variants: "nightfox" (blue), "carbonfox" (grey), "nordfox" (nord),
	--           "terafox" (forest), "duskfox" (purple), "dawnfox" (light)
	--
	{
		"EdenEast/nightfox.nvim",
		priority = 1000,
		opts = {
			options = {
				-- Daltonization: adjusts colors for color vision deficiency.
				-- severity: 0.0 (no shift) to 1.0 (full shift)
				-- type: "deutan" (red-green, most common), "protan" (red-green),
				--       "tritan" (blue-yellow, rare)
				colorblind = {
					enable = true,
					severity = {
						protan = 0.7, -- red weakness compensation
						deutan = 1.0, -- green weakness compensation (most common)
						tritan = 0.0, -- blue-yellow (set >0 if needed)
					},
				},
				-- Style tweaks
				styles = {
					comments = "italic", -- italic comments stand out from code
					keywords = "bold",
				},
			},
			-- Plugin integrations (like catppuccin's)
			groups = {
				all = {
					-- Make git diff colors extra distinct for CVD
					DiffAdd = { fg = "palette.blue" }, -- blue instead of green
					DiffDelete = { fg = "palette.orange" }, -- orange instead of red
				},
			},
		},
	},

	-- Tell LazyVim to actually USE catppuccin as the active colorscheme.
	-- Without this line, LazyVim would still use its default (tokyonight).
	--
	-- To switch to nightfox: change "catppuccin" to "nightfox" (or carbonfox, etc.)
	-- and uncomment the nightfox block above.
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight",
			-- colorscheme = "catppuccin",
			-- colorscheme = "nightfox", -- colorblind: deep blue-purple
			-- colorscheme = "carbonfox",     -- colorblind: neutral grey, minimal hue
			-- colorscheme = "nordfox",       -- colorblind: nord-inspired blue/cyan
			-- colorscheme = "duskfox",       -- colorblind: soft purple/magenta
			-- colorscheme = "terafox",       -- colorblind: warm forest amber
		},
	},
}
