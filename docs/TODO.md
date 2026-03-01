# TODO.md — Open Issues & Feature Backlog

This is the living tracker. Add items freely. Mark done items with ✅ and date. 
AI agents: read this before starting work. If you fix something here, mark it done.

---

## 🔴 Open Bugs

### B1 — Clipboard not working in WSL (Debian, appendWindowsPath=false)
**Status**: ✅ Fixed (online branch, 2026-03-01) — pending `sudo apt install xclip` by user  
**Root cause**: `/etc/wsl.conf` has `appendWindowsPath=false`, so bare `clip.exe` is not in `$PATH`.
The old config used `"clip.exe"` without a full path, causing "not executable" errors.  
**Fix applied** (`options.lua`): WSL detection now uses three-tier fallback:
1. `win32yank.exe` (bidirectional, fastest) — symlink from Windows FS
2. `xclip` via WSLg X11 (`DISPLAY=:0`) — **install: `sudo apt install xclip`**
3. `/mnt/c/Windows/System32/clip.exe` full path — copy-only fallback, no bare name
**User action needed**: `sudo apt install xclip` — once done, clipboard is fully bidirectional.  
**Files**: `nvim/.config/nvim/lua/config/options.lua`

---

### B2 — Clipboard not working in Docker on Linux desktop
**Status**: Open  
**Symptom**: Yanking inside Docker container on Linux desktop doesn't copy to host clipboard.  
**Root cause**: OSC52 approach relies on terminal support. Docker + Ghostty may not propagate OSC52 through `docker exec`/`docker run -it`.  
**Fix needed**: Test OSC52 passthrough in Ghostty specifically. If not working, use `xclip`/`xsel` when `$DISPLAY` is available. Consider `wl-copy` for Wayland.  
**Files**: `nvim/.config/nvim/lua/config/options.lua`

---

### B3 — DAP debugger can't find debugpy
**Status**: Open  
**Symptom**: DAP debugger fails to start, can't locate debugpy.  
**Root cause**: Mason-installed debugpy path resolution is fragile. Multiple pcall wraps added but issue persists.  
**Fix needed**: 
1. Add explicit verification in Dockerfile build: `python -c "import debugpy"` using the exact Mason Python path
2. Check if Mason installs debugpy to a venv or directly
3. If venv: path is `~/.local/share/nvim/mason/packages/debugpy/venv/bin/python`
4. Add CI test: `docker run --network none airgap-dev python3 -c "import debugpy; print(debugpy.__version__)"`
**Debug**: Inside container run `find ~/.local/share/nvim/mason -name "debugpy" -o -name "python" 2>/dev/null`  
**Files**: `nvim/.config/nvim/lua/plugins/python.lua`

---

### B4 — blink.cmp missing libblinkcmp_fuzzy
**Status**: Open  
**Symptom**: blink.cmp fails with missing shared library `libblinkcmp_fuzzy`.  
**Root cause**: blink.cmp uses a precompiled Rust library. When packed into nvim-data tarball, the `.so` file may not be included or has wrong path.  
**Fix needed**: 
1. Locate the library: `find ~/.local/share/nvim/lazy/blink.cmp -name "*.so" -o -name "*.dylib"`
2. Ensure it's included in the `nvim-data` tarball
3. Check if blink.cmp prebuilt binary matches the Ubuntu 24.04 glibc version
4. May need to build from source in Dockerfile instead of using prebuilt
**Files**: `Dockerfile`, `nvim/.config/nvim/lua/plugins/blink.lua`

---

### B5 — Mason packages causing startup errors (dangling packages)
**Status**: ✅ Fixed (online branch, 2026-03-01)
**Root cause**: LazyVim's `lang.python` extra registers both `pyright` and `basedpyright`
in `opts.servers`, causing Mason to attempt installing pyright alongside basedpyright.
**Fix**: Nil out `opts.servers["pyright"]` and `opts.servers["ruff_lsp"]` in a second
`nvim-lspconfig` opts block in `python.lua`. Only basedpyright + ruff are installed.
**Files**: `nvim/.config/nvim/lua/plugins/python.lua`
**Note**: The 3-package rule in GOTCHAS.md was airgap-only. Online branch safely uses 11 packages.

---

### B6 — Telescope workspace symbols fail / "not supported by any server"
**Status**: ✅ Fixed (online branch, 2026-03-01)
**Root cause**: Same as B5 — pyright attaching alongside basedpyright caused `gD` and
`<leader>sP` (document symbols) to fail. Also, `<leader>sW` was calling
`lsp_dynamic_workspace_symbols` which basedpyright doesn't support.
**Fix**: B5 fix removes the duplicate server. `<leader>sW` keymap was already removed;
`<leader>sP` uses `lsp_document_symbols` (basedpyright supports this).

---

### B7 — GHCR push not done
**Status**: Open  
**Symptom**: Docker image not published to `ghcr.io/guylevavi/airgap-dev`.  
**Fix needed**: 
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u GuyLevavi --password-stdin
docker tag airgap-dev:latest ghcr.io/guylevavi/airgap-dev:latest
docker push ghcr.io/guylevavi/airgap-dev:latest
```
Requires `write:packages` token. See [RELEASES.md](RELEASES.md).

---

## 🟡 Improvements

### I1 — Nix AppImage for Neovim (Research Complete, Not Implemented)
**Status**: Research done, implementation pending  
**Value**: Single ~200MB `.AppImage` containing nvim + all plugins + LSPs + parsers. Copy to any Linux machine and run — no installation needed. Perfect for RunAI environments.  
**Approach**: `iofq/nvim.nix` pattern — Nix flake builds nvim with plugins as Nix packages, CI bundles into AppImage via GitHub Actions.  
**Key insight**: Keep `lazy.nvim` for Lua module loading (dependency ordering), but plugins are installed by Nix (not downloaded). Config checks for Nix-injected `lazy_opts` variable; falls back to lazy bootstrap for non-Nix usage.  
**Reference**: https://github.com/iofq/nvim.nix  
**Effort**: High (requires learning Nix, rewriting plugin declarations). Worth doing when current Docker approach becomes painful.  
**Decision needed**: Does nixvim (declarative) or iofq pattern (lazy.nvim preserved) fit better? iofq is better since you keep LazyVim config as-is.

---

### I2 — Tmux: Add omerxx-inspired plugins
**Status**: Partially done (basic settings from omerxx added)  
**Remaining improvements**:
- `tmux-sessionx`: fzf-based session manager with preview (`o` keybind) — **needs network to install via TPM**; must be pre-installed in image
- `tmux-floax`: floating pane overlay (`prefix + p`) — same network constraint
- Both require TPM to be run at Docker build time, not runtime
- Session persistence (`tmux-resurrect` + `tmux-continuum`) — useful for RunAI long sessions  
**Note**: All TPM plugins must be installed at Docker build time. Never `prefix + I` in airgap.

---

### I3 — Python tooling headless tests
**Status**: Not implemented  
**Value**: CI verification that Python LSP, DAP, treesitter all work without network.  
**Plan**: `tests/python-tools.sh` that runs `docker run --network none` and verifies tools.  
See original plan in sprint notes for test script skeleton.

---

### I4 — Marimo improvements
**Status**: Low priority  
**Remaining**: Visual differences from config not visible. May need to verify config file is being read.  
`~/.config/marimo/marimo.toml` should exist with dark theme + vim mode settings.

---

### I5 — nvim-data packing: ensure all lazy plugins included with network=none
**Status**: Open  
**Symptom**: Telescope (and possibly others) fail when network is disabled that work with network enabled.  
**Root cause**: Some plugins may be downloading assets/parsers at first use, not at install time.  
**Fix**: Run nvim with `--network none` in Dockerfile AFTER plugin install, open test files, force lazy-load of all plugins, verify no network calls are attempted.  
```dockerfile
# After plugin install in Dockerfile:
RUN --network=none nvim --headless \
  +"lua require('telescope')" \
  +"lua require('blink.cmp')" \
  +"lua require('nvim-treesitter')" \
  +qa 2>&1 | grep -i "error\|fail\|network" || true
```

---

## ✅ Done

- CI cleanup: removed Fedora jobs from `.github/workflows/pr-tests.yml`
- Bundle reference updated to `devenv-bundle-20260228.tar.gz`
- Clipboard config: yank→system, delete→internal (partially broken, see B1/B2)
- Python autocomplete: `autoImportCompletions = true`, `packageIndexDepths` for torch/numpy/pandas
- Treesitter: `auto_install = false`, gitcommit removed from ensure_installed
- Telescope: `<leader>sP` → `lsp_document_symbols` (reliable)
- Blink.cmp: `pin = true`, explicit `dir` path
- Marimo: binds `0.0.0.0:2718`, dark mode config, vim mode
- Btop locale: `LANG=en_US.UTF-8` in Dockerfile
- DAP: pcall wrappers added (still broken, see B3)
- Autosave: `InsertLeave` + `TextChanged`, no autoformat
- Tmux: omerxx-inspired settings (history, detach-on-destroy, zoom indicator)
- GitHub release v1.8.1 created with bundle
