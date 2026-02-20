# dotfiles-wsl

**Terminal-First ML/CV Dev Environment**

A reproducible, portable terminal development environment designed for Python computer vision and deep learning work in airgapped networks. Built on WSL2 (Fedora/AlmaLinux), LazyVim, and modern CLI tools, managed with GNU Stow so you can `git clone` and be productive in minutes.

> **New to this repo?** Read the [GUIDE.md](GUIDE.md) — a ~1400-line companion document that explains every tool, what it does, why it's here, and how to use it. Written for developers transitioning from GUI/IDE workflows.

---

## What's Included

| Category    | Tools                                                        |
| ----------- | ------------------------------------------------------------ |
| Terminal    | WezTerm (Windows), tmux, starship prompt                     |
| Shell       | zsh + zinit, zoxide, fzf                                     |
| Editor      | Neovim (LazyVim) with Python LSP, DAP debugger, Git, Jupyter REPL |
| File/Search | yazi, ripgrep, fd, bat, eza                                  |
| Git         | lazygit, delta, glab (GitLab CLI)                            |
| Python      | uv (package manager), marimo (stateless notebooks)           |
| Containers  | podman, buildah, skopeo                                      |
| K8s/Cloud   | helm, oc (OpenShift CLI)                                     |
| CI/CD       | jfrog CLI (Artifactory)                                      |

---

## Quick Start (Online)

```bash
# 1. Install WezTerm on Windows, then copy the config
cp wezterm/.wezterm.lua ~

# 2. Install Fedora WSL2 (or use existing AlmaLinux)
powershell -File bootstrap/00-install-fedora-wsl.ps1

# 3. Inside WSL, create your user (as root)
sudo bash bootstrap/01-create-user.sh myuser

# 4. Restart WSL and log in as the new user
wsl --shutdown

# 5. Clone this repo and run setup
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
sudo bash bootstrap/02-install-packages.sh
bash bootstrap/03-install-tools.sh
bash bootstrap/04-stow-dotfiles.sh
bash bootstrap/05-setup-shell.sh
exec zsh
```

After setup, open WezTerm and you're ready to go.

---

## Airgap Workflow

```
Online PC                              Airgapped Network
─────────                              ──────────────────
1. git clone this repo                 3. Copy tarball via approved media
2. bash airgap/bundle.sh              4. Extract and deploy:
   → devenv-bundle-YYYYMMDD.tar.gz       bash airgap/deploy.sh bundle.tar.gz
                                       5. Optional: push to Artifactory
                                          bash airgap/artifactory-push.sh
```

The bundle script downloads all binaries, container images, fonts, and plugin archives into a single tarball. The deploy script unpacks everything and runs the bootstrap steps offline.

---

## Project Structure

```
dotfiles-wsl/
├── bootstrap/                  # Setup scripts (run in order)
│   ├── 00-install-fedora-wsl.ps1   # Install Fedora on WSL2
│   ├── 01-create-user.sh           # Create non-root user with sudo
│   ├── 02-install-packages.sh      # System packages (dnf)
│   ├── 03-install-tools.sh         # User-space tools (uv, starship, etc.)
│   ├── 04-stow-dotfiles.sh         # Symlink configs via GNU Stow
│   └── 05-setup-shell.sh           # Set zsh as default, install zinit
├── airgap/                     # Offline bundle/deploy tooling
│   ├── bundle.sh                    # Build airgap tarball (online machine)
│   ├── deploy.sh                    # Unpack and install (airgapped machine)
│   └── artifactory-push.sh         # Push assets to JFrog Artifactory
├── test-offline.ps1            # Test airgap deployment via WSL clone
├── wezterm/                    # WezTerm config (copy to Windows ~)
│   └── .wezterm.lua
├── tmux/                       # tmux config (stow package)
│   └── .config/tmux/tmux.conf
├── zsh/                        # zsh config (stow package)
│   ├── .zshrc
│   └── .zprofile
├── starship/                   # Starship prompt config (stow package)
│   └── .config/starship.toml
├── nvim/                       # Neovim / LazyVim config (stow package)
│   └── .config/nvim/
│       ├── init.lua
│       └── lua/
│           ├── config/              # LazyVim overrides
│           └── plugins/             # Plugin specs (.lua per plugin)
├── git/                        # Git config (stow package)
│   ├── .gitconfig
│   └── .gitignore_global
├── yazi/                       # Yazi file manager config (stow package)
│   └── .config/yazi/yazi.toml
├── podman/                     # Podman/registries config (stow package)
│   └── .config/containers/
│       └── registries.conf
├── GUIDE.md                    # Comprehensive beginner guide (~1400 lines)
└── README.md
```

Each top-level directory is a GNU Stow package. Running `stow <dir>` from the repo root symlinks its contents into `$HOME`.

---

## Key Bindings Quick Reference

### WezTerm

| Key                    | Action                |
| ---------------------- | --------------------- |
| `Ctrl+Shift+T`         | New tab               |
| `Ctrl+Shift+W`         | Close pane            |
| `Ctrl+Shift+N/P`       | Next / previous tab   |
| `Ctrl+Shift+\|`        | Split horizontal      |
| `Ctrl+Shift+-`         | Split vertical        |
| `Ctrl+Shift+H/J/K/L`  | Navigate panes (vim)  |
| `Ctrl+Shift+Z`         | Zoom pane             |
| `Ctrl+Shift+F`         | Search scrollback     |
| `Ctrl+Shift+X`         | Copy mode (vim keys)  |
| `Ctrl+Shift+Space`     | Quick select mode     |

### tmux (prefix: `Ctrl+a`)

| Key              | Action                |
| ---------------- | --------------------- |
| `Ctrl+a |`       | Vertical split        |
| `Ctrl+a -`       | Horizontal split      |
| `Ctrl+a h/j/k/l` | Navigate panes       |
| `Ctrl+a z`       | Zoom pane             |
| `Ctrl+a c`       | New window            |
| `Ctrl+a n/p`     | Next / previous window |
| `Ctrl+a d`       | Detach session        |
| `Ctrl+a [`       | Enter copy mode (vi)  |

### Neovim / LazyVim (leader: `Space`)

> Press `Space` and wait to see the **which-key** popup with all available bindings.

| Key              | Action                      |
| ---------------- | --------------------------- |
| `Space f f`      | Find files (Telescope)      |
| `Space f g`      | Live grep                   |
| `Space e`        | File explorer (neo-tree)    |
| `Space g g`      | Open lazygit                |
| `Space c a`      | Code actions                |
| `g d`            | Go to definition            |
| `K`              | Hover docs                  |
| `Space d b`      | Toggle breakpoint (DAP)     |
| `Space d c`      | Continue debugging (DAP)    |
| `Space l`        | LazyVim extras menu         |
| `[ d` / `] d`    | Previous / next diagnostic  |

---

## Customization

### Change color scheme

Edit `nvim/.config/nvim/lua/config/lazy.lua` or add a colorscheme plugin in `nvim/.config/nvim/lua/plugins/`. WezTerm colors are set in `wezterm/.wezterm.lua`.

### Add or remove CLI tools

Edit `bootstrap/03-install-tools.sh`. Each tool has its own install block -- comment out or add as needed, then re-run the script.

### Add Neovim plugins

Create a new `.lua` file in `nvim/.config/nvim/lua/plugins/`:

```lua
-- nvim/.config/nvim/lua/plugins/my-plugin.lua
return {
  "author/plugin-name",
  opts = {},
}
```

LazyVim picks it up automatically on next launch.

### Configure GitLab / Artifactory

- **GitLab**: Set your instance URL and auth in `git/.gitconfig` and via `glab auth login`.
- **Artifactory**: Configure the JFrog CLI with `jfrog config add` or edit `airgap/artifactory-push.sh`.
- **Container registries**: Edit `podman/.config/containers/registries.conf` to point at your internal registry.

---

## Python Workflow

### Create a new project

```bash
uv init my-cv-project
cd my-cv-project
uv add torch torchvision opencv-python-headless
```

`uv` manages the virtualenv and lockfile automatically.

### Run and debug Python in Neovim

1. Open a `.py` file.
2. `Space d b` to set breakpoints.
3. `Space d c` to start the DAP debugger (uses debugpy).
4. Use the built-in terminal (`` Ctrl+` ``) or send code to a Jupyter REPL with the molten/iron plugin.

### Marimo notebooks

```bash
uv add marimo
marimo edit notebook.py
```

Marimo notebooks are pure Python files -- no JSON, no hidden state. They diff cleanly in Git.

### Containerized development

```bash
# Build an image with your ML dependencies
podman build -t cv-dev -f Containerfile .

# Run with GPU passthrough (if available)
podman run --rm -it --device nvidia.com/gpu=all cv-dev python train.py

# Save image for airgap transfer
podman save cv-dev | gzip > cv-dev.tar.gz
```

---

## Sharing with Colleagues

1. **Online network**: Have them clone the repo and follow [Quick Start](#quick-start-online).
2. **Airgapped**: Run `bash airgap/bundle.sh` on an online machine, transfer the tarball, and run `bash airgap/deploy.sh` on their machine.
3. **Artifactory**: Push the bundle to your internal Artifactory with `bash airgap/artifactory-push.sh`, then teammates can pull from there.
4. **Customization**: Fork the repo. Each person can maintain their own branch or overlay directory for personal preferences while tracking upstream updates.

---

## Testing the Airgap Bundle

You can test the full offline deployment on your online machine without a second computer:

```powershell
# Full end-to-end test: bundle → clone WSL distro → block network → deploy → verify
.\test-offline.ps1

# Reuse an existing bundle (skip re-downloading)
.\test-offline.ps1 -SkipBundle

# Clean up the test distro when done
.\test-offline.ps1 -Cleanup
```

This exports your WSL distro, imports it as a disposable clone, blocks outbound network via iptables (simulating airgap), resets it to a clean state, and runs the full deploy. All tools and configs are verified automatically.

---

## Troubleshooting

### WSL2 networking issues

```bash
# Reset WSL networking
wsl --shutdown
# In PowerShell (admin):
netsh winsock reset
```

If DNS fails inside WSL, add a manual nameserver:

```bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### Fonts / icon rendering

WezTerm requires a Nerd Font for icons in starship, yazi, and nvim. Install one (e.g., JetBrainsMono Nerd Font) on **Windows** and set it in `.wezterm.lua`:

```lua
config.font = wezterm.font("JetBrainsMono Nerd Font")
```

### Clipboard not working between Neovim and Windows

Ensure `win32yank.exe` is on your Windows PATH, or use the WezTerm/OSC 52 clipboard provider. Check with:

```bash
# Inside WSL
which win32yank.exe
```

### Neovim LSP / treesitter not loading

```vim
:checkhealth
:Lazy sync
:TSUpdate
```

If airgapped, parsers and LSP servers must be included in the bundle. Re-run `airgap/deploy.sh` if they're missing.

### Podman permission errors

```bash
# Fix subuid/subgid mapping
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate
```

### tmux colors look wrong

Ensure your `TERM` is set correctly:

```bash
# In .zshrc or tmux.conf
export TERM=xterm-256color
# tmux.conf
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
```
