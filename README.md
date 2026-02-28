# dotfiles-wsl

**Terminal-First ML/CV Dev Environment**

A reproducible, portable terminal development environment for Python computer vision and deep learning work in airgapped networks.

---

## Quick Start (Docker - Recommended for Airgap)

```bash
# Build airgap bundle (online machine)
git clone https://github.com/GuyLevavi/dotfiles-wsl.git
cd dotfiles-wsl
bash airgap/bundle.sh
# → Creates airgap/devenv-bundle-YYYYMMDD.tar.gz

# Transfer bundle to airgapped network, then build Docker image
docker build -f Dockerfile.airgap-final -t airgap-dev .

# Run container without network access
docker run --network none -it airgap-dev zsh
```

---

## Quick Start (WSL - Online)

```bash
# 1. Install WezTerm on Windows, copy config
cp wezterm/.wezterm.lua ~

# 2. Install Fedora WSL2 (or Ubuntu)
powershell -File bootstrap/00-install-fedora-wsl.ps1

# 3. Inside WSL, setup as root
sudo bash bootstrap/01-create-user.sh gl
wsl --shutdown

# 4. Login as new user, clone and setup
git clone https://github.com/GuyLevavi/dotfiles-wsl.git ~/dotfiles && cd ~/dotfiles
sudo bash bootstrap/02-install-packages.sh
bash bootstrap/03-install-tools.sh
bash bootstrap/04-stow-dotfiles.sh
bash bootstrap/05-setup-shell.sh
exec zsh
```

---

## Airgap Workflow

```
Online PC                    Airgapped Network
───────────                  ─────────────────
1. git clone                3. Transfer bundle tarball
2. bash airgap/bundle.sh    4. Build & run Docker image
   → devenv-bundle-*.tar.gz
```

**Bundle includes:** 25+ CLI tools, system packages, zsh plugins, nvim plugins, Python wheels.

---

## Airgap Neovim Usage

When working in the airgapped container, all Neovim plugins and tools are pre-installed. **Do NOT run update commands** - they require network access.

### What NOT to do (requires network):
- `:Lazy sync` - tries to update plugins from GitHub
- `:MasonInstall <package>` - tries to download LSP tools  
- `:TSInstall <parser>` - tries to compile/download parsers
- `:UpdateRemotePlugins` - tries to update remote plugins

### What TO do:
- Just run `nvim` - everything is ready
- Use `<leader>ff` for telescope file finder
- Use `<leader>fg` for live grep
- Use `<leader>e` for file explorer
- Python LSP (basedpyright) is ready to go

### If you need to add new plugins:
1. Add plugin spec to `nvim/.config/nvim/lua/plugins/`
2. Rebuild the Docker image with network access
3. The new plugin will be baked into the image

### What's pre-installed:
- **50+ plugins** in `~/.local/share/nvim/lazy/`
- **12 Mason packages** in `~/.local/share/nvim/mason/packages/`
  - basedpyright, ruff, debugpy (Python)
  - yaml-language-server, json-lsp, dockerfile-language-server
  - markdownlint-cli2, markdown-toc
  - shfmt, stylua, hadolint, tree-sitter-cli
- **33 treesitter parsers** in `~/.local/share/nvim/site/parser/`

---

## Tools Overview

| Category    | Tools                                                        |
| ----------- | ------------------------------------------------------------ |
| Terminal    | WezTerm, tmux, starship                                      |
| Shell       | zsh + zinit, zoxide, fzf                                     |
| Editor      | Neovim (LazyVim) with Python LSP, debugger, REPL             |
| File/Search | yazi, ripgrep, fd, bat, eza                                  |
| Git         | lazygit, delta, glab                                         |
| Python      | uv, marimo, jupyter, jupytext                                |
| Containers  | podman, buildah, skopeo, lazydocker                          |
| K8s/Cloud   | helm, oc, k9s                                                |
| System      | btop, lnav, glow, fastfetch                                  |
| Dev Tools   | zig cc (C compiler), posting (HTTP client)                   |

---

## Docker Images

| Image | Description | Use Case |
|-------|-------------|----------|
| `ghcr.io/guylevavi/airgap-dev:latest` | Pre-built airgap image | Run directly without building |
| `Dockerfile.airgap-final` | Build from bundle | Custom builds with your bundle |

**Build and run:**
```bash
# Build locally
docker build -f Dockerfile.airgap-final -t airgap-dev:latest .

# Run with port forwarding for marimo/jupyter
docker run -it -p 2718:2718 -p 8888:8888 airgap-dev:latest zsh

# Run completely offline (no network)
docker run --network none -it airgap-dev:latest zsh
```

---

## Marimo & Jupyter in Docker

When running the airgap-dev container, expose ports to access marimo/jupyter from your browser:

```bash
# Start container with port forwarding
docker run -it -p 2718:2718 -p 8888:8888 airgap-dev:latest zsh

# Inside container, start marimo tutorial
marimo tutorial intro --host 0.0.0.0 --port 2718

# Or start marimo edit mode
marimo edit notebook.py --host 0.0.0.0 --port 2718

# Access from Windows browser:
# http://localhost:2718

# For Jupyter (if needed):
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser
```

**Note**: Always use `--host 0.0.0.0` to bind to all interfaces, otherwise the server won't be accessible from outside the container.

---

## Bundle Release History

See [airgap/BUNDLE_HISTORY.md](airgap/BUNDLE_HISTORY.md) for complete changelog.

| Bundle | Date | Size | Key Changes |
|--------|------|------|-------------|
| `devenv-bundle-20260228.tar.gz` | 2026-02-28 | 516MB | Ubuntu-only, btop+lnav+new TUI tools, 26 total tools |
| `devenv-bundle-20260226-ubuntu.tar.gz` | 2026-02-26 | 513MB | Dual-distro support (deprecated) |

**Latest Release:** v1.8.1

---

## Project Structure

```
dotfiles-wsl/
├── bootstrap/       # Setup scripts (01-05)
├── airgap/          # Offline bundle/deploy
│   ├── bundle.sh    # Create bundle from online machine
│   ├── deploy.sh    # Deploy bundle to airgapped machine
│   └── cache/       # Downloaded tools and packages
├── nvim/            # Neovim config (LazyVim-based)
├── zsh/             # Shell config (zinit-based)
├── tmux/            # Multiplexer config
├── marimo/          # Notebook config
└── ...              # Other stow packages
```

Each directory is a GNU Stow package. Run `stow <dir>` to symlink into `$HOME`.

---

## Key Bindings

**Tmux** (prefix `Ctrl+a`):
- `|` / `-` — Split horizontal/vertical
- `h/j/k/l` — Navigate panes
- `z` — Zoom pane
- `c` — New window

**Neovim** (leader `Space`):
- `Space f f` — Find files
- `Space f g` — Live grep
- `Space e` — File explorer
- `Space g g` — LazyGit
- `gd` — Go to definition
- `K` — Hover docs

See GUIDE.md for complete reference.

---

## Python Workflow

```bash
# Create project
uv init my-project && cd my-project
uv add torch torchvision opencv-python-headless
uv add --dev pytest ruff mypy

# Run and debug
uv run python train.py
nvim  # Space d b (breakpoint), Space d c (continue)

# Notebooks
marimo edit notebook.py
jupyter lab
```

---

## Documentation

- **GUIDE.md** — Complete tool reference and tutorials
- **RUNAI.md** — Run:ai cluster deployment guide
- **AGENTS.md** — Project context for AI assistants
- **airgap/BUNDLE_HISTORY.md** — Bundle changelog

---

## Customization

Add/remove tools in `bootstrap/03-install-tools.sh`. Add nvim plugins in `nvim/.config/nvim/lua/plugins/`. Fork and maintain your own branch.

---

## Known Issues

- **Btop UTF-8 locale**: Fixed in latest bundle (UTF-8 locales now generated)
- **Nvim clipboard**: Fixed in latest bundle (xclip now installed)
- **Which-key icons**: Some Nerd Font icons may not display in Docker (terminal-dependent)
- **Tmux font rendering**: Fonts are handled by the host terminal (WezTerm on Windows), not by the container
