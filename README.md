# dotfiles-wsl

**Terminal-First ML/CV Dev Environment**

A reproducible, portable terminal development environment for Python computer vision and deep learning work in airgapped networks.

---

## Quick Start (Online)

```bash
# 1. Install WezTerm on Windows, copy config
cp wezterm/.wezterm.lua ~

# 2. Install Fedora WSL2
powershell -File bootstrap/00-install-fedora-wsl.ps1

# 3. Inside WSL, setup as root
sudo bash bootstrap/01-create-user.sh myuser
wsl --shutdown

# 4. Login as new user, clone and setup
git clone <repo-url> ~/dotfiles && cd ~/dotfiles
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
1. git clone                3. Transfer tarball
2. bash airgap/bundle.sh    4. bash airgap/deploy.sh bundle.tar.gz
   → devenv-bundle-*.tar.gz
```

**Bundle includes:** 25+ CLI tools, system packages, zsh plugins, nvim plugins.

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

| Base | Tag |
|------|-----|
| Fedora 43 | `ghcr.io/guylevavi/dotfiles-wsl:latest` |
| RHEL/UBI 9 | `ghcr.io/guylevavi/dotfiles-wsl:latest-ubi9` |
| Ubuntu 24.04 | `ghcr.io/guylevavi/dotfiles-wsl:latest-ubuntu2404` |

**Usage:**
```bash
# With airgap bundle
docker run -it --rm \
  -v /path/to/bundle.tar.gz:/bundle.tar.gz \
  ghcr.io/guylevavi/dotfiles-wsl:latest \
  bash airgap/deploy.sh --user gl --force /bundle.tar.gz

# Layer on corporate base image (see RUNAI.md)
```

---

## Project Structure

```
dotfiles-wsl/
├── bootstrap/       # Setup scripts (01-05)
├── airgap/          # Offline bundle/deploy
├── nvim/            # Neovim config
├── zsh/             # Shell config
├── tmux/            # Multiplexer config
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

## Testing Airgap Bundle

```powershell
# Full end-to-end test
.\test-offline.ps1

# Reuse existing bundle
.\test-offline.ps1 -SkipBundle
```

---

## Documentation

- **GUIDE.md** — Complete tool reference and tutorials
- **RUNAI.md** — Run:ai cluster deployment guide
- **AGENTS.md** — Project context for AI assistants

---

## Customization

Add/remove tools in `bootstrap/03-install-tools.sh`. Add nvim plugins in `nvim/.config/nvim/lua/plugins/`. Fork and maintain your own branch.
