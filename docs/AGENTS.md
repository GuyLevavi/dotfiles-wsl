# AGENTS.md — Project Context for AI Assistants

## Quick Reference

| Topic | File |
|-------|------|
|-------|------|
| Architecture & bootstrap | This file §Architecture |
| Airgap pipeline | This file §Airgap |
| WSL / Windows quirks | [docs/GOTCHAS.md](docs/GOTCHAS.md) |
| Neovim conventions | [docs/NVIM.md](docs/NVIM.md) |
| Environment parity (WSL ↔ Docker) | [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md) |
| Versioning & release process | [docs/RELEASES.md](docs/RELEASES.md) |
| Prompting guide (for weaker models) | [docs/PROMPTING.md](docs/PROMPTING.md) |
| **Open bugs & feature backlog** | [TODO.md](TODO.md) |

**Always read the relevant doc before touching that subsystem.**

---

## What This Is

Dotfiles repo for a **WSL2-based Python CV/DL development environment**.

The same environment runs in two targets — they must stay in parity:

| Target | Use |
|--------|-----|
| **WSL2** (FedoraLinux-43 → migrating to Ubuntu 24.04) | Local development on Windows machine |
| **Docker** (Ubuntu 24.04) | Deployed to RunAI GPU cluster, attached via `runai exec` |

Everything must work **offline after initial bundle creation**. No network access at runtime.

See [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md) for the full parity contract and RunAI workflow.

---

## Architecture

### Repo Layout

Each root directory is a GNU Stow package mirroring `$HOME`:

```
zsh/.zshrc                → ~/.zshrc
nvim/.config/nvim/        → ~/.config/nvim/
starship/.config/         → ~/.config/starship.toml
tmux/.config/tmux/        → ~/.config/tmux/
git/.gitconfig            → ~/.gitconfig
podman/.config/           → ~/.config/containers/
opencode/.config/         → ~/.config/opencode/
codex/.codex/             → ~/.codex/
```

> **Stow symlinks parent dirs**, not individual files. `~/.config/nvim` is a directory
> symlink, so `test -L ~/.config/nvim/init.lua` returns false. Always use `test -f`.

### Bootstrap Scripts (`bootstrap/`, run in order)

| Script | Runs as | Purpose |
|--------|---------|---------|
| `00-install-fedora-wsl.ps1` | Windows/PowerShell | Installs Fedora 43 WSL (legacy) |
| `01-create-user.sh` | root | Creates user `gl` (uid 1000, wheel) |
| `02-install-packages.sh` | root | DNF or APT system packages (`--minimal` skips build deps) |
| `03-install-tools.sh` | user | Downloads/installs 18 CLI tools → `~/.local/bin` |
| `04-stow-dotfiles.sh` | user | Stow all packages, backs up conflicts |
| `05-setup-shell.sh` | root | Sets zsh as default shell |

Scripts are distro-aware. See §Multi-distro.

---

## Airgap Pipeline

### Components

```
airgap/
  bundle.sh       ← online machine: downloads everything → devenv-bundle-YYYYMMDD.tar.gz
  deploy.sh       ← offline machine: extracts bundle, runs bootstrap 02-05 --offline
  versions.lock   ← pinned versions; bundle.sh writes it, 03-install-tools.sh reads it
  cache/
    rpms/         ← Fedora/RHEL system packages
    debs/         ← Ubuntu/Debian system packages
    *.tar.gz      ← tool binaries (see §Tool Cache Filenames)
```

### Tool Cache Filenames (must match between bundle.sh and 03-install-tools.sh)

```
starship.tar.gz, zoxide.tar.gz, fzf.tar.gz, bat.tar.gz, eza.tar.gz,
ripgrep.tar.gz, fd.tar.gz, yazi.zip, lazygit.tar.gz, uv.tar.gz,
glab.tar.gz, jf, delta.tar.gz, nvim.appimage, helm.tar.gz, oc.tar.gz,
fastfetch.tar.gz, mc
```

### Airgap Rules

- `glab` is on GitLab. Use `gl_latest()` (GitLab API at `gitlab.com/api/v4/projects/{url-encoded}/releases`), NOT `gh_latest()`.
- `bundle.sh` auto-detects host distro → downloads RPMs or DEBs accordingly.
- `deploy.sh` detects target distro → passes correct cache dir to `02-install-packages.sh --offline`.

### Testing

`test-offline.ps1` — end-to-end test: exports WSL, imports clone, blocks network via nftables, deploys bundle, verifies 27 checks (18 tools + 9 configs).

---

## Multi-Distro Support

### Supported Base Images (Docker)

| Variant | Base image | Tag |
|---------|-----------|-----|
| Ubuntu 24.04 (primary) | `ubuntu:24.04` | `-ubuntu2404` / `:latest` |
| Fedora 43 (legacy) | `registry.fedoraproject.org/fedora:43` | *(deprecated)* |
| RHEL/UBI 9 | `registry.access.redhat.com/ubi9/ubi:latest` | `-ubi9` |

**Ubuntu 24.04 is the canonical target.** Fedora CI jobs have been removed. Don't add Fedora-specific logic.

### Package Name Differences

| Purpose | Fedora/RHEL | Ubuntu/Debian |
|---------|-------------|---------------|
| Python headers | `python3-devel` | `python3-dev` |
| ShellCheck | `ShellCheck` | `shellcheck` |
| Process utils | `procps-ng` | `procps` |
| XZ utils | `xz` | `xz-utils` |

---

## Current Environment State

### Installed (baked into Docker image / deployed via bundle)

| Category | What | Count |
|----------|------|-------|
| CLI tools | starship, zoxide, fzf, bat, eza, ripgrep, fd, yazi, lazygit, uv, glab, jf, delta, nvim, helm, oc, fastfetch, mc | 18 |
| Nvim plugins | Lazy-managed, pre-installed in `~/.local/share/nvim/lazy/` | ~50 |
| Mason packages | basedpyright, ruff, debugpy **(exactly 3 — others cause errors)** | 3 |
| Treesitter parsers | Pre-compiled in `~/.local/share/nvim/site/parser/` | 33 |

### Key Behaviors (current)

- **Clipboard**: Yank (`y`) → system clipboard. Delete (`dd`, `x`) → internal nvim register.
  - WSL: `xclip` via WSLg X11 (install: `sudo apt install xclip`) → falls back to full-path `/mnt/c/Windows/System32/clip.exe` (bare `clip.exe` fails: `appendWindowsPath=false` in `/etc/wsl.conf`)
  - Docker on Linux: OSC52 terminal escape sequences
  - Headless (no DISPLAY, not WSL): internal only, shows notification
- **Autosave**: on `InsertLeave` + `TextChanged`. Autoformat is OFF (`vim.g.autoformat = false`). Manual format: `<leader>cf`.
- **Python LSP**: basedpyright with `autoImportCompletions = true`, `packageIndexDepths` for torch/numpy/pandas.
- **Treesitter**: `auto_install = false` (critical for airgap).
- **Blink.cmp**: `pin = true`, explicit `dir` path set.
- **Lazy checker**: disabled (`checker = { enabled = false }`).
- **Marimo**: binds `0.0.0.0:2718`, dark mode, vim mode, JetBrainsMono, auto-browser disabled.
- **Btop**: `LANG=en_US.UTF-8` / `LC_ALL=en_US.UTF-8` set in Dockerfile.
- **OpenCode theme**: `"tokyonight"` (no hyphen — `"tokyo-night"` causes black fallback).

---

## Critical Conventions

### DO NOT

- Do NOT run `:Lazy sync`, `:MasonInstall`, or `:TSInstall` in airgap — all require network.
- Do NOT add plugins without rebuilding the Docker image (plugins must be baked in).
- Do NOT use `test -L` to check stow symlinks — use `test -f`.
- Do NOT use `"tokyo-night"` as a theme name — use `"tokyonight"`.
- Do NOT add Fedora-specific CI jobs or package logic.
- Do NOT commit directly to main — work on feature branches, create PRs.
- Do NOT commit proactively — user asks explicitly for commits.

### Colorblind Accessibility (deuteranopia)

Never use red for status/errors. Use:
- 🟠 Orange `#ff9e64` for errors/warnings
- 🔵 Blue for info
- 🟣 Magenta for accents

### LazyVim Extras Over Manual Config

Use LazyExtras for LSP/tool setup. Extras are imported in `nvim/.config/nvim/lua/config/lazy.lua` (lines ~61-84).
**Do NOT duplicate what LazyExtras already provides.**
The `lazyvim.json` extras array is empty — the `lazy.lua` imports are what enables them.

### Minimal Configs

Remove bloat. If the default is good, don't override it. Configs must be minimal and commented so a vim beginner can understand them.

### Version Pinning

`airgap/cache/versions.lock` pins all tool versions. `bundle.sh` writes it; `03-install-tools.sh --offline` reads it. Both must agree on cache filenames (see §Tool Cache Filenames).

---

## Environment Details

- **WSL distro**: FedoraLinux-43 (local legacy) / Ubuntu 24.04 (target)
- **User**: `gl` (uid 1000, wheel group)
- **Shell**: zsh + zinit + starship prompt
- **Editor**: Neovim 0.11+ with LazyVim
- **Terminal**: WezTerm (Windows-side — NOT managed by stow, manually sync `C:\Users\guyle\.wezterm.lua`)
- **Theme**: Tokyo Night everywhere
- **Font**: JetBrainsMono Nerd Font

---

## GitHub CLI

GitHub CLI is at `"C:\Program Files\GitHub CLI\gh.exe"` — not in PATH. Use full path for `gh` commands.

---

## Workflow

- Feature branches → PRs (not direct commits to main)
- User asks explicitly for commits — don't commit proactively
- Install latest versions of tools by default
- After changes: create PR and push
- See [docs/RELEASES.md](docs/RELEASES.md) for release/bundle process
