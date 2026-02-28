# NVIM.md — Neovim Configuration Guide

Referenced from [AGENTS.md](../AGENTS.md). Read this before touching any file under `nvim/`.

---

## File Map

```
nvim/.config/nvim/
  init.lua                        ← entry point (minimal, don't touch)
  lazyvim.json                    ← extras array intentionally empty; see lazy.lua instead
  lua/
    config/
      lazy.lua                    ← LazyExtras imports (lines ~61-84) + lazy.nvim bootstrap
      options.lua                 ← vim options, clipboard detection, autosave
      keymaps.lua                 ← custom keymaps (create if missing)
    plugins/
      blink.lua                   ← completion (blink.cmp), pin=true, explicit dir
      python.lua                  ← basedpyright LSP, ruff, debugpy DAP — all pcall-wrapped
      treesitter.lua              ← parsers, auto_install=false (CRITICAL)
      editor.lua                  ← telescope keymaps, workspace/document symbols
      [other plugins].lua         ← one file per plugin or plugin group
```

---

## Core Rules

### LazyExtras First

Use LazyExtras for LSP/tool setup wherever possible. Extras are imported in `lazy.lua` lines ~61-84.

**Do NOT duplicate what LazyExtras provides.** Before adding manual LSP config, check if a LazyExtra exists. The `lazyvim.json` extras array is intentionally empty — the `lazy.lua` imports are authoritative.

### Minimal & Commented

Remove bloat. If the default is correct, don't override it. Every non-obvious line needs a comment explaining *why*, not *what*. A vim beginner should be able to read any plugin file and understand it.

### One Plugin Per File

Keep `lua/plugins/` files focused. Don't bundle unrelated plugins together.

---

## Airgap Rules for Nvim

### What's Pre-installed (don't re-download)

| Location | Contents |
|----------|----------|
| `~/.local/share/nvim/lazy/` | ~50 plugins |
| `~/.local/share/nvim/mason/packages/` | **3 packages only**: basedpyright, ruff, debugpy |
| `~/.local/share/nvim/site/parser/` | 33 Treesitter parsers |

### Commands That Require Network — NEVER RUN IN AIRGAP

```
:Lazy sync          ← tries to update plugins from GitHub
:Lazy update        ← same
:MasonInstall X     ← tries to download LSP tools
:TSInstall X        ← tries to compile/download parsers
```

### Required Config Guards (must not be removed)

```lua
-- lazy.lua
checker = { enabled = false }       -- disables update checker

-- treesitter.lua
auto_install = false                 -- CRITICAL: prevents network on filetype detection

-- blink.lua
pin = true                           -- prevents update checks
dir = vim.fn.stdpath("data") .. "/lazy/blink.cmp"  -- explicit local path
```

### Verifying Airgap in Dockerfile

After plugin install, always run a network=none smoke test:
```dockerfile
RUN --network=none nvim --headless \
  +"lua require('telescope.builtin').find_files()" \
  +"lua require('blink.cmp')" \
  +qa 2>&1 | grep -i "error\|fail\|network" || true
```

### Adding New Plugins

1. Add plugin spec to `nvim/.config/nvim/lua/plugins/`
2. Rebuild Docker image (with network access)
3. The new plugin is baked in — do NOT `:Lazy install` after deploy

---

## Mason — Exactly 3 Packages

Only these are valid. **Any others cause startup errors (dangling packages).**

```lua
-- In any plugin file using mason ensure_installed:
ensure_installed = { "basedpyright", "ruff", "debugpy" }
```

Do NOT add: `pyright` (conflicts with basedpyright), `docker-compose`, `lua_ls`, `marksman`, or anything else unless deliberately adding full config for it.

---

## Python Tooling

### LSP Stack

| Tool | Role | Installed via |
|------|------|--------------|
| basedpyright | Type checking + completion | Mason |
| ruff | Linting + formatting | Mason |
| debugpy | DAP debugging | Mason |

### Basedpyright Config (python.lua)

```lua
basedpyright = {
  settings = {
    python = {
      analysis = {
        autoImportCompletions = true,
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        packageIndexDepths = {
          { name = "torch", depth = 5 },
          { name = "numpy", depth = 4 },
          { name = "pandas", depth = 4 },
        },
      },
    },
  },
}
```

**Note**: basedpyright does NOT support `textDocument/documentSymbol` on all files. Use `lsp_document_symbols` with explicit symbol filter, not workspace symbols.

### DAP (Debugpy) — Resilient Path Resolution

Status: **currently broken** (see TODO.md B3). Use this pattern:

```lua
local function find_debugpy_python()
  -- Try Mason venv first
  local mason_path = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
  if vim.fn.executable(mason_path) == 1 then
    -- Verify debugpy is actually importable
    local ok = vim.fn.system(mason_path .. ' -c "import debugpy" 2>/dev/null')
    if vim.v.shell_error == 0 then return mason_path end
  end
  -- Fallback to system python with debugpy
  for _, py in ipairs({"python3", "python"}) do
    if vim.fn.executable(py) == 1 then
      vim.fn.system(py .. ' -c "import debugpy" 2>/dev/null')
      if vim.v.shell_error == 0 then return py end
    end
  end
  return nil
end

-- Always wrap setup in pcall
local python = find_debugpy_python()
if python then
  local ok, err = pcall(require("dap-python").setup, python)
  if not ok then vim.notify("DAP setup failed: " .. err, vim.log.levels.WARN) end
end
```

Debug inside container:
```bash
find ~/.local/share/nvim/mason/packages/debugpy -name "python" 2>/dev/null
~/.local/share/nvim/mason/packages/debugpy/venv/bin/python -c "import debugpy; print(debugpy.__version__)"
```

### Blink.cmp Sources

Ensure LSP is in default sources (not just buffer):
```lua
sources = {
  default = { "lsp", "path", "snippets" },
  -- NOT { "buffer", "lsp" } — buffer gives untyped word completions
}
```

### blink.cmp — libblinkcmp_fuzzy

blink.cmp requires a precompiled Rust `.so`. Verify it's present:
```bash
find ~/.local/share/nvim/lazy/blink.cmp -name "*.so"
```
If missing, blink.cmp must be compiled from source in Dockerfile. See TODO.md B4.

---

## Telescope Symbol Search

| Keymap | Command | Notes |
|--------|---------|-------|
| `<leader>sP` | `lsp_document_symbols` | **Reliable** — use this |
| `<leader>sW` | `lsp_workspace_symbols` | Unreliable — basedpyright doesn't fully support it |

Document symbols (`lsp_document_symbols`) is the correct choice for Python. Do not attempt to fix workspace symbols — basedpyright doesn't fully implement the protocol.

---

## Clipboard

See [GOTCHAS.md](GOTCHAS.md#clipboard-in-different-contexts) for the full auto-detection logic including win32yank setup.

Summary: `y`/`yy`/`Y` → system clipboard (`+` register). `dd`/`d`/`x` → internal unnamed register.

**Current status**: Ghostty clipboard broken (TODO.md B1). Docker Linux clipboard may be broken (TODO.md B2).

---

## Autosave & Format

```lua
-- options.lua
vim.g.autoformat = false    -- autoformat OFF; manual: <leader>cf

-- Autosave triggers: InsertLeave, TextChanged
```

---

## Treesitter

```lua
-- treesitter.lua
opts = {
  auto_install = false,  -- NEVER remove this in airgap
  ensure_installed = { ... },  -- parsers pre-compiled; don't add without rebuilding image
}
```

`gitcommit` was removed from `ensure_installed` — it was triggering network access on git commit buffers.

---

## Debugging Nvim in Container

```bash
# Check which LSP clients are attached
nvim --headless -c 'lua print(vim.inspect(vim.lsp.get_active_clients()))' -c 'qa'

# Check blink.cmp plugin spec
nvim --headless -c 'lua print(vim.inspect(require("lazy.core.config").spec.plugins["blink.cmp"]))' -c 'qa'

# Verify no network calls on startup (CRITICAL test)
docker run --network none airgap-dev:latest nvim --headless +qa 2>&1

# Check Mason package list
ls ~/.local/share/nvim/mason/packages/
# Expected: basedpyright  debugpy  ruff  (exactly these 3)
```

In a live nvim session:
- `:LspInfo` — which LSPs are attached to current buffer
- `:Lazy` — plugin manager UI (read-only safe in airgap)
- `:Mason` — Mason package status (read-only safe)
- `:checkhealth` — general health check
- `:checkhealth clipboard` — verify clipboard provider
