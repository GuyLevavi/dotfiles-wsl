# Airgap Dependencies Audit

This document lists all tools, CLI binaries, nvim plugins, and their offline/airgap capabilities.

**Last Updated:** 2025-02-25

---

## CLI Tools - Offline Capability Status

### ✅ Fully Offline (No Runtime Downloads)

| Tool | Version Source | Offline Behavior | Notes |
|------|----------------|------------------|-------|
| starship | GitHub releases | ✅ Works fully offline | Single binary, no external deps |
| zoxide | GitHub releases | ✅ Works fully offline | Single binary, database stored locally |
| fzf | GitHub releases | ✅ Works fully offline | Single binary, no network needed |
| bat | GitHub releases | ✅ Works fully offline | Single binary, themes baked in |
| eza | GitHub releases | ✅ Works fully offline | Single binary, no network |
| ripgrep (rg) | GitHub releases | ✅ Works fully offline | Single binary, PCRE2 statically linked |
| fd | GitHub releases | ✅ Works fully offline | Single binary, no external deps |
| yazi | GitHub releases | ✅ Works fully offline | Single binary + ya helper |
| lazygit | GitHub releases | ✅ Works fully offline | Single Go binary, git operations local |
| delta | GitHub releases | ✅ Works fully offline | Single binary, themes baked in |
| nvim | GitHub releases (AppImage) | ✅ Works fully offline | AppImage extracts, Mason plugins bundled separately |
| uv | GitHub releases | ✅ Works fully offline | Single binary, Python downloads can be disabled |
| glab | GitLab releases | ✅ Works fully offline | Single binary, GitLab API calls only on use |
| jf (jfrog) | Direct download | ✅ Works fully offline | Single binary |
| helm | GitHub releases | ✅ Works fully offline | Single binary, talks to cluster only |
| oc | OpenShift mirror | ✅ Works fully offline | Includes kubectl, talks to cluster only |
| fastfetch | GitHub releases | ✅ Works fully offline | Single binary, detects system locally |
| mc (minio) | MinIO archive | ✅ Works fully offline | Single binary, S3 operations only |
| k9s | GitHub releases | ✅ Works fully offline | Single binary, talks to k8s API only |
| lazydocker | GitHub releases | ✅ Works fully offline | Single binary, talks to Docker socket only |
| btop | GitHub releases | ✅ Works fully offline | Single binary, reads /proc locally |
| lnav | GitHub releases | ✅ Works fully offline | Single binary, SQLite embedded |
| glow | GitHub releases | ✅ Works fully offline | Single binary, renders markdown locally |
| zig | Zig website | ✅ Works fully offline | Full C/C++ compiler toolchain, no external deps |

### ⚠️ Needs Dependencies Bundled

| Tool | Install Method | Dependencies | Offline Strategy |
|------|----------------|----------------|------------------|
| harlequin | uv tool install | Needs adapters: postgres, sqlite | Install with extras: `uv tool install 'harlequin[postgres,sqlite]'` |
| posting | uv tool install | Pure Python, may need certifi/ssl | `uv tool install posting` caches all deps |
| marimo | uv tool install | Pure Python + dependencies | `uv tool install marimo` caches all deps |
| jupyter | uv tool install | Pure Python + many deps | `uv tool install jupyter` caches all deps |
| jupytext | uv tool install | Pure Python | `uv tool install jupytext` caches all deps |
| pytest | uv tool install | Pure Python, needed for neotest-python | `uv tool install pytest` or include in Python venv |

### 🔧 How to Handle Python Tools in Airgap

```bash
# On ONLINE machine - pre-cache Python tool wheels
mkdir -p airgap/cache/wheels

# Install tools and copy wheels from uv cache
cd airgap/cache/wheels
uv tool install harlequin --python 3.11
uv tool install 'harlequin[postgres,sqlite]'

# Extract wheels from uv cache
cp -r ~/.cache/uv/wheels/*.whl ./ 2>/dev/null || true

# Alternative: pip download (more reliable for airgap)
pip download harlequin --no-deps -d ./
pip download harlequin harlequin-postgres -d ./
```

---

## Neovim/LazyVim - Offline Capability

### ✅ Core Plugins (Fully Offline)

All plugins in `lazy-lock.json` are sourced from GitHub and can be bundled:

```bash
# Bundle location
~/.local/share/nvim/lazy/          # All plugin code
~/.local/state/nvim/mason/         # LSP/DAP/formatter packages
~/.cache/nvim/                     # Treesitter parsers (compiled .so files)
```

### ⚠️ Mason Packages (Need Pre-installation)

| Package | Type | Airgap Strategy |
|---------|------|-----------------|
| pyright | LSP | `MasonToolsInstallSync` in prep-nvim.sh |
| ruff | LSP/formatter | `MasonToolsInstallSync` |
| debugpy | DAP | `MasonToolsInstallSync` |
| lua-language-server | LSP | `MasonToolsInstallSync` |
| stylua | Formatter | `MasonToolsInstallSync` |
| bash-language-server | LSP | `MasonToolsInstallSync` |
| shfmt | Formatter | `MasonToolsInstallSync` |
| json-lsp | LSP | `MasonToolsInstallSync` |
| yaml-language-server | LSP | `MasonToolsInstallSync` |
| markdown-oxide | LSP | `MasonToolsInstallSync` |

### Treesitter Parsers

Treesitter parsers are **compiled C libraries** (.so files), not Lua code.

```bash
# Offline compilation needs C compiler
export CC="zig cc"  # Uses zig as standalone C compiler

# Pre-compile all parsers on online machine
nvim --headless -c "TSUpdateSync" -c "qa"

# Bundle compiled parsers
~/.cache/nvim/treesitter/  # Contains parser.so files
```

### Nightfox Colorscheme

✅ **Fully offline** - Lua-based colorscheme, no compilation needed.

- Already included in `lazy-lock.json`
- Daltonization (colorblind support) configured in `colorscheme.lua`
- No external dependencies or downloads at runtime

---

## Zsh Plugins - Offline Capability

All zsh plugins are cloned from GitHub and stored locally:

```
~/.local/share/zinit/plugins/       # Plugin code (fully offline)
```

Bundled as tarballs in airgap/cache/:
- zinit.tar.gz
- fast-syntax-highlighting.tar.gz
- zsh-autosuggestions.tar.gz
- zsh-completions.tar.gz
- fzf-tab.tar.gz

✅ All work fully offline once extracted.

---

## Critical Airgap Checklist

### Pre-Deployment (Online Machine)

1. **CLI Tools**: Run `bundle.sh` to download all 25 binaries
2. **Zsh Plugins**: Cloned automatically by `bundle.sh`
3. **nvim Plugins**: 
   - Run `prep-nvim.sh` to sync all lazy plugins
   - Run `MasonToolsInstallSync` to install all Mason packages
   - Run `TSUpdateSync` to compile treesitter parsers
   - Create `nvim-data.tar.gz` with all data
4. **Python Tools**:
   - Option A: Install via `uv tool install` and cache wheels
   - Option B: Skip, install manually on target
5. **System Packages**:
   - Fedora: `dnf download --resolve` (done by bundle.sh)
   - Ubuntu: `apt-get install --download-only` (done by bundle.sh)

### Deployment (Airgap Machine)

1. Extract bundle: `tar -xzf devenv-bundle-*.tar.gz`
2. Run `deploy.sh --offline`
3. Verify: All binaries in ~/.local/bin/
4. Verify: nvim loads without network
5. Verify: pytest available for neotest-python

### Post-Deployment Checks

```bash
# Verify all CLI tools
for tool in starship zoxide fzf bat eza rg fd yazi lazygit delta nvim uv glab jf helm oc fastfetch mc k9s lazydocker btop lnav glow zig; do
  which $tool || echo "MISSING: $tool"
done

# Verify nvim plugins
ls ~/.local/share/nvim/lazy/ | wc -l  # Should be 50+ plugins
ls ~/.local/state/nvim/mason/packages/  # Should have pyright, ruff, etc
ls ~/.cache/nvim/treesitter/  # Should have .so files

# Verify zsh plugins
ls ~/.local/share/zinit/plugins/  # Should have 4+ plugins

# Verify Python
python3.10 --version
python3.11 --version
pytest --version
```

---

## Known Issues & Solutions

### Issue: Mason packages have hardcoded paths
**Problem**: Python-based LSPs (like pyright) use venvs with absolute paths.

**Solution**: 
- Mason 2.0+ uses relative symlinks (better for portability)
- If moving between systems, run `:MasonToolsInstallSync` after first launch
- Or use `prep-nvim.sh` on the same distro type as target

### Issue: Treesitter parsers need compilation
**Problem**: Parsers are .so files compiled for specific architecture.

**Solution**: 
- Pre-compile on same architecture as target
- Use zig cc to avoid system lib dependencies
- Bundle compiled parsers from ~/.cache/nvim/treesitter/

### Issue: Python wheels platform-specific
**Problem**: Many Python packages have compiled extensions.

**Solution**:
- Use `--platform manylinux_x86_64` when downloading
- Or install on target using system Python + pip
- Or use pure-Python alternatives where possible

### Issue: Harlequin adapters not installed
**Problem**: `uv tool install harlequin` only installs base, not adapters.

**Solution**:
```bash
# Install with extras BEFORE bundling
uv tool install 'harlequin[postgres,mysql,sqlite,mongodb,redis]'
# Or for airgap, bundle wheels:
uv tool install --find-links ./wheels harlequin
```

---

## Recommended Airgap Strategy

### Phase 1: Bundle Creation (Online)

```bash
# 1. Download all CLI binaries
bash airgap/bundle.sh

# 2. Prepare nvim with all plugins
bash airgap/prep-nvim.sh

# 3. Optional: Pre-install Python tools with wheels
mkdir -p airgap/cache/wheels
pip download 'harlequin[postgres,sqlite]' -d airgap/cache/wheels/
pip download posting jupyter jupytext pytest -d airgap/cache/wheels/

# 4. Create bundle
tar -czf devenv-bundle-$(date +%Y%m%d).tar.gz airgap/cache/
```

### Phase 2: Deployment (Airgap)

```bash
# 1. Extract and deploy
bash airgap/deploy.sh --offline devenv-bundle-*.tar.gz

# 2. Install Python tools (if wheels bundled)
uv tool install --find-links airgap/cache/wheels harlequin

# 3. Verify
bash airgap/verify.sh  # Run verification script
```

---

## Summary Table: Can It Run Airgapped?

| Component | Offline Ready | Needs Bundle | Notes |
|-----------|---------------|--------------|-------|
| starship | ✅ | Binary only | - |
| zoxide | ✅ | Binary only | - |
| fzf | ✅ | Binary only | - |
| bat | ✅ | Binary only | - |
| eza | ✅ | Binary only | - |
| ripgrep | ✅ | Binary only | - |
| fd | ✅ | Binary only | - |
| yazi | ✅ | Binary only | - |
| lazygit | ✅ | Binary only | - |
| delta | ✅ | Binary only | - |
| nvim | ✅ | Binary + data | Needs plugins bundled |
| uv | ✅ | Binary only | Disable auto-download |
| glab | ✅ | Binary only | - |
| jf | ✅ | Binary only | - |
| helm | ✅ | Binary only | - |
| oc | ✅ | Binary only | - |
| fastfetch | ✅ | Binary only | - |
| mc | ✅ | Binary only | - |
| k9s | ✅ | Binary only | - |
| lazydocker | ✅ | Binary only | - |
| btop | ✅ | Binary only | - |
| lnav | ✅ | Binary only | - |
| glow | ✅ | Binary only | - |
| zig | ✅ | Binary only | - |
| harlequin | ⚠️ | Binary + wheels | Needs adapters bundled |
| posting | ⚠️ | Binary + wheels | Pure Python, needs wheels |
| marimo | ⚠️ | Binary + wheels | Pure Python, needs wheels |
| jupyter | ⚠️ | Binary + wheels | Many dependencies |
| jupytext | ⚠️ | Binary + wheels | Pure Python |
| pytest | ⚠️ | Binary + wheels | Needed for neotest |
| zsh plugins | ✅ | Tarballs | Extracted from bundle |
| nvim plugins | ✅ | Tarballs | Extracted from bundle |
| Mason packages | ✅ | Pre-installed | Install via MasonToolsInstallSync |
| Treesitter | ✅ | Pre-compiled | Compile with zig cc |
