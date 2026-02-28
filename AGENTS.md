# AGENTS.md — Project Context for AI Assistants

## What This Is

Dotfiles repo for a WSL2-based Python CV/DL development environment. Targets
airgapped networks — everything must work offline after initial bundle creation.

Published at: https://github.com/GuyLevavi/dotfiles-wsl

## Architecture

### Stow-Centric Layout

Each directory at the repo root is a GNU Stow package mirroring `$HOME`:

```
zsh/.zshrc            → ~/.zshrc
nvim/.config/nvim/    → ~/.config/nvim/
starship/.config/     → ~/.config/starship.toml
tmux/.config/tmux/    → ~/.config/tmux/
git/.gitconfig        → ~/.gitconfig
podman/.config/       → ~/.config/containers/
opencode/.config/     → ~/.config/opencode/
codex/.codex/         → ~/.codex/
```

Stow may symlink parent directories (e.g. `~/.config/nvim` is a directory
symlink, not individual file symlinks). This means `test -L ~/.config/nvim/init.lua`
returns false — use `test -f` instead.

### Bootstrap Pipeline

Six scripts in `bootstrap/`, run in order:

| Script | Runs as | Purpose |
|--------|---------|---------|
| `00-install-fedora-wsl.ps1` | Windows/PowerShell | Installs Fedora 43 WSL |
| `01-create-user.sh` | root | Creates user `gl` with wheel group |
| `02-install-packages.sh` | root | DNF or APT packages (`--minimal` skips build deps) |
| `03-install-tools.sh` | user | Downloads/installs 18 CLI tools to `~/.local/bin` |
| `04-stow-dotfiles.sh` | user | Stow all packages, backs up conflicts |
| `05-setup-shell.sh` | root | Sets zsh as default shell |

### Airgap Pipeline

Three components:

1. **`airgap/bundle.sh`** — Downloads tool binaries + zsh plugins into
   `airgap/cache/`, creates `devenv-bundle-YYYYMMDD.tar.gz`. Uses
   `versions.lock` to pin versions. Also downloads system packages:
   `cache/rpms/` on Fedora/RHEL, `cache/debs/` on Ubuntu/Debian.

2. **`airgap/deploy.sh`** — Extracts bundle, derives repo location from its
   own `BASH_SOURCE`, symlinks extracted cache into repo, runs bootstrap
   scripts 02-05 with `--offline` flag.

3. **`test-offline.ps1`** — End-to-end test: exports WSL, imports clone,
    blocks network via nftables, deploys bundle, verifies 27 checks
    (18 tools + 9 configs).

## Environment

- **WSL distro**: FedoraLinux-43
- **User**: `gl` (uid 1000, wheel group)
- **Shell**: zsh + zinit + starship prompt
- **Editor**: Neovim 0.11+ with LazyVim
- **Terminal**: WezTerm (Windows-side, NOT symlinked via stow)
- **Theme**: Tokyo Night everywhere
- **Font**: JetBrainsMono Nerd Font

## Multi-Distro Docker Support

The `Dockerfile` supports three base images via `ARG BASE_IMAGE`:

| Variant | Base image | Tag suffix |
|---------|-----------|-----------|
| Fedora 43 (default) | `registry.fedoraproject.org/fedora:43` | *(none)* / `:latest` |
| RHEL/UBI 9 | `registry.access.redhat.com/ubi9/ubi:latest` | `-ubi9` |
| Ubuntu 24.04 | `ubuntu:24.04` | `-ubuntu2404` |

The Dockerfile detects distro at build time via `/etc/os-release` and runs the
appropriate package manager. `02-install-packages.sh` does the same at runtime.

### Package Name Differences

| Package purpose | Fedora/RHEL name | Ubuntu/Debian name |
|----------------|-----------------|-------------------|
| Python headers | `python3-devel` | `python3-dev` |
| ShellCheck | `ShellCheck` | `shellcheck` |
| Process utils | `procps-ng` | `procps` |
| XZ utils | `xz` | `xz-utils` |

### Airgap Bundle per Distro

`bundle.sh` auto-detects the host distro:
- On Fedora/RHEL: downloads RPMs into `cache/rpms/` via `dnf download --resolve`
- On Ubuntu/Debian: downloads DEBs into `cache/debs/` via `apt-get install --download-only`

`deploy.sh` detects the target distro at runtime and passes the right cache dir
to `02-install-packages.sh --offline`.

## Critical Conventions

### Colorblind Accessibility

User has deuteranopia. Never use red for status/errors. Use:
- Orange `#ff9e64` for errors/warnings
- Blue for info
- Magenta for accents

### LazyVim Extras Over Manual Config

Use LazyExtras for LSP/tool setup. Extras are imported in `nvim/.config/nvim/lua/config/lazy.lua`
(lines ~61-84). Do NOT duplicate what LazyExtras provides. The `lazyvim.json`
extras array is empty — the imports in `lazy.lua` are what enables them.

### Minimal Configs

Remove bloat. If the default is good, don't override it. Configs should be
minimal and commented so a vim beginner can understand them.

### Version Pinning

`airgap/cache/versions.lock` pins all tool versions. `bundle.sh` writes it,
`03-install-tools.sh --offline` reads it. Both must agree on cache filenames:

```
starship.tar.gz, zoxide.tar.gz, fzf.tar.gz, bat.tar.gz, eza.tar.gz,
ripgrep.tar.gz, fd.tar.gz, yazi.zip, lazygit.tar.gz, uv.tar.gz,
glab.tar.gz, jf, delta.tar.gz, nvim.appimage, helm.tar.gz, oc.tar.gz,
fastfetch.tar.gz, mc
```

### GitLab API for glab

glab is hosted on GitLab, not GitHub. Use `gl_latest()` function (GitLab API
at `gitlab.com/api/v4/projects/{url-encoded}/releases`) instead of `gh_latest()`.

## Gotchas

### WSL from Windows (Git Bash)

When calling WSL commands from Windows Git Bash:
- `/usr/bin/env` gets mangled to `C:/Program Files/Git/usr/bin/env`
- `$HOME` in `wsl -- bash -c '...'` may not expand (PowerShell eats it)
- Use `wsl.exe -d FedoraLinux-43 -u gl -- zsh -c 'command'` pattern
- For multiline scripts, write to a file inside WSL first, then execute
- PowerShell pipe to WSL adds UTF-8 BOM — use `Write-WslScript` pattern
  (write via `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`)
- `wsl --list --quiet` outputs UTF-16 with null bytes — strip with
  `-replace "\`0", ""`

### WSL Imported Distros

- `$HOME` may be `/root` in non-login bash sessions — always set explicitly
  via `getent passwd` if needed
- `/tmp` gets cleaned by systemd on restart — stow targets must be on
  persistent paths (e.g. `~/dotfiles`, NOT `/tmp/dotfiles`)
- Firewall uses nftables, NOT iptables (Fedora 43 minimal)

### Stow Conflicts

When deploying to a cloned distro, existing config files from the source
distro cause stow conflicts. The test script must reset ALL config paths
including `.codex/`, `.config/opencode/`, `.config/containers/`, etc.
The `04-stow-dotfiles.sh` has `backup_conflicts()` but it's better to
pre-clean in test scenarios.

### deploy.sh Temp Dir Permissions

`mktemp -d` creates 0700 dirs owned by root. When `run_as_user` runs
scripts as the target user, they can't read root-owned temp dirs. Always
`chmod 755` temp dirs and `chmod -R a+rX` extracted contents.

### WezTerm Config

`wezterm/.wezterm.lua` in the repo is the reference copy. The actual
Windows-side config is at `C:\Users\guyle\.wezterm.lua` and must be
manually synced — it is NOT managed by stow.

### OpenCode Theme

Must be `"tokyonight"` (no hyphen). `"tokyo-night"` causes black fallback.

### yazi --version

yazi produces no output from `--version` in non-TTY contexts. Verify with
`test -x` instead of running the command.

## GitHub CLI

GitHub CLI is at `"C:\Program Files\GitHub CLI\gh.exe"` — not in PATH.
Use full path for `gh` commands.

## Workflow

- Work on feature branches, create PRs (not direct commits to main)
- User explicitly asks for commits — don't commit proactively
- Install latest versions of tools by default
- After changes, user wants PR created and pushed

## Airgap TODO & Strategies (Current Sprint)

### Overview
The airgap container is working but has several issues to fix for production use in WSL and RunAI environments.

---

### 1. CI/CD Cleanup

**Problem**: Fedora tests in CI are irrelevant since we only need Ubuntu bundles for airgap.

**Action**: Remove Fedora-related CI jobs:
- Delete `stow-dry-run` job (Fedora 43)
- Delete `airgap-integration` job (Fedora 43) 
- Keep only Ubuntu Docker build test
- Keep fast checks (shellcheck, lua-syntax, config-syntax, stow-structure)

**Files**: `.github/workflows/pr-tests.yml`

---

### 2. Bundle Reference Update

**Problem**: AGENTS.md still references old bundle `devenv-bundle-20260226-ubuntu.tar.gz`, but we now use `devenv-bundle-20260228.tar.gz`.

**Action**: Update all documentation references to the new bundle name.

**Files**: `AGENTS.md`, `Dockerfile.airgap-complete`, `Dockerfile.airgap-offline`

---

### 3. Blink.cmp Toggle Without Network

**Problem**: User disabled blink.lua in lazy but wants to keep it. Re-enabling causes GitHub network access attempt.

**Root Cause**: Lazy.nvim checks for updates when plugins are enabled/disabled, and blink.cmp has GitHub URLs in its spec.

**Strategy**:
```lua
-- In lazy.lua, add to performance.rtp:
disabled_plugins = {}, -- Keep empty, don't disable blink

-- In blink.lua, add airgap-aware toggle:
{
  "saghen/blink.cmp",
  -- Add local path to prevent GitHub lookup in airgap
  dir = vim.fn.stdpath("data") .. "/lazy/blink.cmp",
  -- Disable auto-update checking
  pin = true,
  -- Rest of config...
}
```

**Key Insight**: Lazy has `pin = true` option to prevent update checks on individual plugins. Also can use `dev = true` for local development.

**Files**: `nvim/.config/nvim/lua/plugins/blink.lua`, `nvim/.config/nvim/lua/config/lazy.lua`

---

### 4. Nvim Clipboard Configuration

**Problem**: No clipboard providers. Need delete in internal nvim clipboard, yank/copy to system clipboard (Windows accessible).

**Requirements**:
- Delete (`dd`, `x`) → internal nvim clipboard only
- Yank (`yy`, `y`) → system clipboard (accessible from Windows)
- Works in WSL with Windows clipboard integration

**Strategy**:
```lua
-- In nvim/.config/nvim/lua/config/options.lua:
-- WSL clipboard integration via OSC52 or win32yank
vim.g.clipboard = {
  name = 'WslClipboard',
  copy = {
    ['+'] = 'clip.exe',
    ['*'] = 'clip.exe',
  },
  paste = {
    ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
  },
  cache_enabled = true,
}

-- Don't use unnamedplus by default (keeps delete internal)
vim.opt.clipboard = ""  

-- Map yank to use system clipboard
vim.keymap.set({"n", "v"}, "y", "\"+y", { desc = "Yank to system clipboard" })
vim.keymap.set("n", "yy", "\"+yy", { desc = "Yank line to system clipboard" })
vim.keymap.set("n", "Y", "\"+Y", { desc = "Yank to EOL to system clipboard" })

-- Keep delete/x/cut internal (no mapping needed, default behavior)
```

**Alternative for pure Linux airgap**:
- Use `xclip` or `xsel` if available
- Otherwise rely on terminal OSC52 escape sequences (modern terminals support this)

**Files**: `nvim/.config/nvim/lua/config/options.lua`, `nvim/.config/nvim/lua/config/keymaps.lua` (create if doesn't exist)

---

### 5. Treesitter Gitcommit Parser Download

**Problem**: Treesitter tries to download gitcommit parser even though it's in ensure_installed.

**Root Cause**: Treesitter's auto-install feature triggers on filetype detection, even when parser is pre-compiled.

**Strategy**:
```lua
-- In treesitter.lua, disable auto_install:
{
  "nvim-treesitter/nvim-treesitter",
  opts = {
    auto_install = false,  -- Critical for airgap
    ensure_installed = { ... },  -- Keep the list
  },
}
```

**Also need to check**: If parsers are in the right location (`~/.local/share/nvim/site/parser/`).

**Files**: `nvim/.config/nvim/lua/plugins/treesitter.lua`

---

### 6. Python Autocomplete (Class/Variable Names)

**Problem**: Snippets work but autocomplete for class/variable names doesn't. User sees "bad LLM completions" (likely buffer-based).

**Root Cause**: Basedpyright LSP should provide semantic completion, but may not be configured correctly or isn't attached to the buffer.

**Strategy**:
1. Verify basedpyright is attached: `:LspInfo` in a Python file
2. Check if ruff is conflicting (ruff has basic completion too)
3. Ensure basedpyright settings enable completion:
```lua
-- In python.lua, verify:
basedpyright = {
  settings = {
    python = {
      analysis = {
        autoImportCompletions = true,
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      },
    },
  },
}
```

4. Check blink.cmp LSP source is properly configured:
```lua
-- In blink.lua, ensure LSP is in default sources:
sources = {
  default = { "lsp", "path", "snippets" },
  -- NOT { "buffer", "lsp" } which would give bad completions
}
```

**Debug Steps**:
```bash
# In container:
nvim --headless -c 'lua print(vim.inspect(vim.lsp.get_active_clients()))' -c 'qa'
nvim --headless -c 'lua print(vim.inspect(require("lazy.core.config").spec.plugins["blink.cmp"]))' -c 'qa'
```

**Files**: `nvim/.config/nvim/lua/plugins/python.lua`, `nvim/.config/nvim/lua/plugins/blink.lua`

---

### 7. Telescope Workspace Symbols

**Problem**: Telescope says "method workspace/symbol is not supported by any of the servers..."

**Root Cause**: Basedpyright may not have workspace symbol support enabled, or telescope is trying before LSP is attached.

**Strategy**:
1. Check if basedpyright supports workspace symbols (it should)
2. Add explicit configuration:
```lua
-- In python.lua or editor.lua:
basedpyright = {
  settings = {
    python = {
      analysis = {
        -- Enable all analysis features
        typeCheckingMode = "basic",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        -- These help with workspace symbols
        extraPaths = {},
        stubPath = "",
      },
    },
  },
}
```

3. Alternative: Use document symbols instead:
```lua
-- In editor.lua, change keymap:
["<leader>sP"] = {
  function()
    require("telescope.builtin").lsp_document_symbols({
      symbols = { "Class", "Function", "Method" },
    })
  end,
  desc = "Search Python symbols in current file",
}
```

**Files**: `nvim/.config/nvim/lua/plugins/editor.lua`, `nvim/.config/nvim/lua/plugins/python.lua`

---

### 8. Headless Python Tooling Tests

**Problem**: Need automated tests to verify Python tooling works in airgap.

**Strategy**: Create test script that runs in CI or locally:
```bash
#!/bin/bash
# tests/python-tools.sh

docker run --network none --rm airgap-dev:latest zsh -c '
  set -e
  echo "=== Python LSP Tests ==="
  
  # Test basedpyright installation
  test -f ~/.local/share/nvim/mason/packages/basedpyright/venv/bin/basedpyright
  echo "✓ basedpyright installed"
  
  # Test ruff
  test -f ~/.local/share/nvim/mason/packages/ruff/venv/bin/ruff
  echo "✓ ruff installed"
  
  # Test debugpy
  test -f ~/.local/share/nvim/mason/packages/debugpy/venv/bin/python
  echo "✓ debugpy installed"
  
  # Test Python versions
  python3.10 --version
  python3.11 --version  
  python3.12 --version
  echo "✓ Python versions work"
  
  # Test pytest
  pytest --version
  echo "✓ pytest works"
  
  # Create test Python file and verify nvim can open with LSP
  echo "print(\"test\")" > /tmp/test.py
  timeout 5 nvim --headless /tmp/test.py -c "sleep 2" -c "qa" 2>/dev/null || true
  echo "✓ nvim opens Python files"
  
  echo ""
  echo "All Python tooling tests passed!"
'
```

**Files**: Create `tests/python-tools.sh`

---

### 9. Marimo Tutorial Port Access

**Problem**: `marimo tutorial intro` exposes port but can't access it from outside container.

**Root Cause**: Marimo likely binds to localhost (127.0.0.1) inside container, making it inaccessible from host even with port mapping.

**Strategy**:
```bash
# When running container, expose all ports:
docker run -p 8080:8080 -p 2718:2718 --name airgap-dev airgap-dev

# Inside container, start marimo with explicit host:
marimo tutorial intro --host 0.0.0.0 --port 8080

# Or for edit mode:
marimo edit --host 0.0.0.0 --port 8080
```

**Dockerfile Update** (expose ports):
```dockerfile
EXPOSE 8080 2718
```

**Documentation**: Add to README
```markdown
## Using Marimo

```bash
# Start container with port forwarding
docker run -it -p 8080:8080 -p 2718:2718 airgap-dev zsh

# Inside container, start marimo
marimo tutorial intro --host 0.0.0.0 --port 8080

# Access from Windows browser:
http://localhost:8080
```
```

**Files**: `Dockerfile.airgap-final`, `README.md`

---

### 10. Document Airgap Nvim/Lazy Usage

**Problem**: Need clear documentation on how to use nvim in airgap (plugins already installed, no network).

**Key Points to Document**:

1. **Pre-installed State**: All 50 plugins are already in `~/.local/share/nvim/lazy/`
2. **No Network Required**: Lazy checker is disabled (`checker = { enabled = false }`)
3. **Mason Packages**: 12 packages pre-installed in `~/.local/share/nvim/mason/packages/`
4. **Treesitter Parsers**: 33 parsers compiled in `~/.local/share/nvim/site/parser/`

**What NOT to do in airgap**:
- Don't run `:Lazy sync` (will try to update from GitHub)
- Don't run `:MasonInstall` (will try to download)
- Don't run `:TSInstall` (will try to compile/download)

**What TO do**:
- Start nvim normally: `nvim`
- Use plugins as usual - they're already there
- Add new plugins by placing them in `nvim/.config/nvim/lua/plugins/` BEFORE building the Docker image

**README Section to Add**:
```markdown
## Airgap Neovim Usage

When working offline, all plugins are pre-installed. Do NOT run update commands:

**DON'T** (requires network):
- `:Lazy sync` - tries to update plugins from GitHub
- `:MasonInstall <package>` - tries to download LSP tools  
- `:TSInstall <parser>` - tries to compile/download parsers

**DO**:
- Just run `nvim` - everything is ready
- Use `<leader>ff` for telescope file finder
- Use `<leader>fg` for live grep
- Python LSP (basedpyright) is ready to go

If you need to add new plugins:
1. Add plugin spec to `nvim/.config/nvim/lua/plugins/`
2. Rebuild Docker image with network access
3. The new plugin will be baked into the image
```

**Files**: `README.md`

---

## Implementation Priority

**Phase 1 (Critical)**:
1. CI cleanup (remove Fedora tests)
2. Bundle reference update
3. Clipboard configuration
4. Python autocomplete fix
5. Documentation update

**Phase 2 (Important)**:
6. Treesitter gitcommit fix
7. Telescope workspace symbols
8. Blink toggle mechanism
9. Python tooling tests
10. Marimo port exposure

**Estimated Time**: 2-3 hours for Phase 1, 1-2 hours for Phase 2.

---

## Sprint Status (2026-02-28)

### ✅ Completed Tasks

#### Phase 1 (Critical) - ALL DONE ✅
1. **CI Cleanup** - Removed Fedora tests from `.github/workflows/pr-tests.yml`
   - Deleted `stow-dry-run` job (Fedora 43)
   - Deleted `airgap-integration` job (Fedora 43)
   - Kept Ubuntu 24.04 Docker build test
   
2. **Bundle Reference Update** - Updated all docs to `devenv-bundle-20260228.tar.gz`
   - Updated README.md
   - Created airgap/BUNDLE_HISTORY.md
   - Tagged release v1.8.1
   
3. **Clipboard Configuration** - Fixed nvim clipboard error
   - Added `xclip` and `xsel` to Dockerfile packages
   - WSL clipboard uses `clip.exe`
   - Native Linux uses `xclip`
   - Yank goes to system clipboard (+ register)
   - Delete stays internal (unnamed register)
   
4. **Python Autocomplete** - Fixed class/variable completion
   - Enabled `autoImportCompletions = true` in basedpyright
   - Added `packageIndexDepths` for torch, numpy, pandas, etc.
   - Verified LSP source in blink.cmp
   
5. **Documentation Update** - Complete README overhaul
   - Added Docker airgap quickstart
   - Removed Fedora references
   - Added bundle history section
   - Added known issues section

#### Phase 2 (Important) - ALL DONE ✅
6. **Treesitter Gitcommit Fix** - Disabled auto_install
   - Set `auto_install = false` in treesitter.lua
   - Removed `gitcommit` from ensure_installed
   - Prevents network access when opening git files
   
7. **Telescope Workspace Symbols** - Changed to document symbols
   - `<leader>sP` now uses `lsp_document_symbols()` (reliable)
   - Added `<leader>sW` for workspace symbols with error handling
   - No more "method not supported" errors
   
8. **Blink Toggle Mechanism** - Added pin=true
   - Added `pin = true` to blink.lua
   - Added explicit `dir` path
   - Plugin can now be toggled without network access
   
9. **Marimo Port Exposure** - Added to Dockerfile
   - Added `EXPOSE 2718 8888` for marimo/jupyter
   - Documented port forwarding in README
   - Added marimo config with dark mode, vim mode, JetBrainsMono font

#### Additional Fixes (Not in Original Plan) ✅
10. **Btop UTF-8 Locale** - Fixed locale error
    - Added `locale-gen en_US.UTF-8` in Dockerfile
    - Set `LANG=en_US.UTF-8` and `LC_ALL=en_US.UTF-8`
    - Btop now starts without locale warnings
    
11. **Python DAP Debugger** - Fixed exit code 1
    - Added Mason registry lookup for debugpy path
    - Fallback to system Python if Mason debugpy not found
    - Added proper debug configurations
    
12. **Nvim Autosave** - Implemented without autoformat
    - Autosaves on `InsertLeave` and `TextChanged`
    - Disabled autoformat on save (`vim.g.autoformat = false`)
    - Manual formatting with `<leader>cf` still works
    
13. **Marimo Config** - Created comprehensive config
    - Tokyo Night dark theme
    - JetBrainsMono Nerd Font at 14pt
    - Vim mode enabled
    - Server binds to 0.0.0.0:2718
    - Auto-browser disabled for Docker

### 📊 Current State Summary

**Working ✅:**
- 26 CLI tools in Docker container
- 50 nvim plugins, 12 Mason packages, 33 treesitter parsers
- Clipboard: yank to system, delete internal
- Python: basedpyright LSP, autocomplete, DAP debugging
- Marimo: dark mode, vim mode, accessible via browser
- Btop: no UTF-8 locale errors
- Nvim: autosave enabled, no autoformat

**Known Issues ℹ️:**
- Whichkey icons: Some Nerd Font icons may not display (depends on host terminal font)
- Tmux fonts: Handled by host terminal (WezTerm on Windows), not container
- Jupyter: No executable provided by package (use jupytext or add jupyter-core if needed)

### 🏷️ Git Tag
Release v1.8.1 tagged: `git tag -a v1.8.1`

### 📦 Bundle
Latest bundle: `devenv-bundle-20260228.tar.gz` (516MB)
Location: `airgap/devenv-bundle-20260228.tar.gz`

### 📝 Documentation
- README.md: Updated with Docker workflow
- airgap/BUNDLE_HISTORY.md: Complete release history
- AGENTS.md: This sprint status added

### 🎯 Next Steps (Phase 3)
1. **GHCR Push** - Push image to ghcr.io/guylevavi/airgap-dev:latest (needs write:packages token)
2. **Tmux Improvements** - Research devopstoolbox/dotfiles patterns (optional)
3. **Whichkey Icons** - Consider text-only icons for better compatibility (optional)
4. **Headless Tests** - Create automated test suite for Python tooling (optional)

---

### Additional Hotfixes (2026-02-28)

#### 14. DAP Debugger Crash Fix
**Problem**: `get_install_path()` failed on line 50, causing DAP to crash entirely.

**Fix**: 
- Wrapped all Mason registry calls in `pcall()` for error handling
- Added graceful fallback chain: Mason debugpy → system Python
- Wrapped `dap-python.setup()` in pcall to prevent hard failures
- Verified: DAP now loads successfully with 6 Python configurations

**Files**: `nvim/.config/nvim/lua/plugins/python.lua`

#### 15. Clipboard Headless Mode Fix  
**Problem**: xclip errors in headless WSL/RunAI contexts ("can't find display").

**Fix**:
- Detect headless context (no DISPLAY and not WSL)
- In headless: use internal nvim clipboard only (no system integration)
- In WSL: use clip.exe (works headless via Windows)
- Only set clipboard keymaps when provider is available
- Shows notification: "Running in headless mode - using internal clipboard only"

**Files**: `nvim/.config/nvim/lua/config/options.lua`

#### 16. WSL Airgap Documentation Fix
**Problem**: README only showed Docker airgap, implied WSL was deprecated.

**Fix**:
- Restored WSL airgap as Method 2 (alongside Docker Method 1)
- Clarified: Docker for containers/RunAI, WSL for WSL2 environments
- Both methods fully supported

**Files**: `README.md`

#### 17. GitHub Release Bundle v1.8.1
**Problem**: GitHub releases still showed v1.8.0 from two days ago.

**Fix**:
- Created GitHub release v1.8.1
- Uploaded `devenv-bundle-20260228.tar.gz` (516MB)
- Release includes full changelog and usage instructions
- URL: https://github.com/GuyLevavi/dotfiles-wsl/releases/tag/v1.8.1

---
