# Bundle Release History

This document tracks all releases of the airgap development environment bundles.

---

## Release Format

Bundles are named: `devenv-bundle-YYYYMMDD[-variant].tar.gz`
- `YYYYMMDD` - Release date
- `variant` - Optional distro variant (e.g., `ubuntu`, `fedora`)

---

## Release History

### v1.8.1 (2026-02-28) - Current
**Bundle:** `devenv-bundle-20260228.tar.gz`
**Size:** 516MB

**Key Changes:**
- ✅ Switched to Ubuntu 24.04 only (removed Fedora support)
- ✅ Added 26 CLI tools (up from 18):
  - New: btop, lnav, k9s, lazydocker, glow, zig cc
  - Existing: starship, zoxide, fzf, bat, eza, ripgrep, fd, yazi
  - Existing: lazygit, delta, nvim, uv, glab, helm, oc, kubectl, fastfetch, mc
- ✅ Added xclip/xsel for nvim clipboard support
- ✅ Added UTF-8 locale generation for btop
- ✅ Pre-installed Python tools: marimo, posting, jupytext, harlequin
- ✅ 50 nvim plugins, 12 Mason packages, 33 treesitter parsers
- ✅ Fixed Python DAP debugger configuration
- ✅ Added nvim autosave without autoformat
- ✅ Added marimo config (dark mode, vim mode, JetBrainsMono font)

**Fixes:**
- Clipboard error (xclip not found)
- Btop UTF-8 locale warning
- Python DAP exit code 1
- Autocomplete for classes/variables in Python

---

### v1.8.0 (2026-02-26)
**Bundle:** `devenv-bundle-20260226-ubuntu.tar.gz`
**Size:** 513MB

**Key Changes:**
- Dual-distro support (Fedora 43 and Ubuntu 24.04)
- 18 CLI tools
- 50 nvim plugins with LazyVim
- Basic airgap container support

**Note:** Deprecated in favor of Ubuntu-only v1.8.1

---

### v1.7.0 and earlier

Earlier releases focused on WSL2 Fedora setup. See git tags for history:
- v1.7.2 - Last Fedora-focused release
- v1.7.0 - Added airgap bundle support
- v1.6.0 - Added Docker support
- v1.5.x - Initial WSL setup

---

## Checksums

### v1.8.1 (2026-02-28)
```
SHA256: (generate with: sha256sum devenv-bundle-20260228.tar.gz)
MD5: (generate with: md5sum devenv-bundle-20260228.tar.gz)
```

### v1.8.0 (2026-02-26)
```
Bundle: devenv-bundle-20260226-ubuntu.tar.gz
Size: 537MB (compressed)
SHA256: Available on GitHub Releases
```

---

## Tools Included by Version

### v1.8.1 (26 tools)

| Tool | Version | Purpose |
|------|---------|---------|
| starship | latest | Shell prompt |
| zoxide | latest | Smart cd |
| fzf | latest | Fuzzy finder |
| bat | latest | Syntax-highlighting cat |
| eza | latest | Modern ls |
| ripgrep | latest | Fast grep |
| fd | latest | Fast find |
| yazi | latest | File manager |
| lazygit | latest | Git TUI |
| delta | latest | Git diff viewer |
| nvim | 0.11+ | Editor |
| uv | latest | Python package manager |
| glab | latest | GitLab CLI |
| helm | latest | Kubernetes package manager |
| oc | latest | OpenShift CLI |
| kubectl | bundled | Kubernetes CLI |
| fastfetch | latest | System info |
| mc | latest | MinIO client |
| k9s | latest | Kubernetes TUI |
| lazydocker | latest | Docker TUI |
| btop | latest | System monitor |
| lnav | latest | Log viewer |
| glow | latest | Markdown viewer |
| zig | 0.13.0 | C compiler |

### Python Tools (installed via uv)
- marimo - Reactive notebooks
- posting - HTTP client
- jupytext - Jupyter notebooks
- harlequin - SQL IDE

---

## Mason Packages (v1.8.1)

| Package | Purpose |
|---------|---------|
| basedpyright | Python LSP |
| ruff | Python linter/formatter |
| debugpy | Python debugger |
| yaml-language-server | YAML LSP |
| json-lsp | JSON LSP |
| dockerfile-language-server | Dockerfile LSP |
| markdownlint-cli2 | Markdown linter |
| markdown-toc | Markdown TOC generator |
| shfmt | Shell formatter |
| stylua | Lua formatter |
| hadolint | Dockerfile linter |
| tree-sitter-cli | Treesitter CLI |

---

## Upgrade Notes

### From v1.8.0 to v1.8.1
- **Breaking:** Fedora support removed, use Ubuntu-only bundle
- **New:** 8 additional CLI tools (btop, lnav, k9s, lazydocker, glow, zig, etc.)
- **Fix:** Clipboard, locale, and DAP issues resolved
- **Docker:** Rebuild required with new Dockerfile.airgap-final

### From v1.7.x to v1.8.x
- **Breaking:** Bundle format changed (single Ubuntu bundle vs multi-distro)
- **New:** Docker-based airgap workflow (recommended)
- **Migration:** Use bundle.sh to regenerate

---

## Retention Policy

- **Latest 3 versions**: Full support, bug fixes
- **Versions 4-6 months old**: Security fixes only
- **Older versions**: Archived, no support

---

## Download

Bundles are available on GitHub Releases:
https://github.com/GuyLevavi/dotfiles-wsl/releases

Or generate your own:
```bash
cd dotfiles-wsl
bash airgap/bundle.sh
```
