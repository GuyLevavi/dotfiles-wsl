# Airgap Bundle Distro Compatibility Guide

## TL;DR

| Component | Fedora Bundle | UBI9 Bundle | Ubuntu Bundle |
|-----------|---------------|-------------|---------------|
| **CLI tools** (starship, fzf, nvim, etc.) | ✅ Same binaries | ✅ Same binaries | ✅ Same binaries |
| **System packages** (zsh, tmux, git) | RPMs | RPMs | DEBs |
| **nvim data** (plugins, Mason, treesitter) | ✅ Portable | ✅ Portable | ✅ Portable |
| **zsh plugins** | ✅ Same | ✅ Same | ✅ Same |

**Conclusion**: The nvim data bundle is **architecture-specific** (x86_64), NOT distro-specific. You can use the Fedora nvim-data.tar.gz on UBI9 or Ubuntu.

---

## Detailed Breakdown

### What Varies by Distro

#### 1. System Packages (`cache/rpms/` or `cache/debs/`)
- **Fedora/UBI9**: Downloads `.rpm` files via `dnf download --resolve`
- **Ubuntu/Debian**: Downloads `.deb` files via `apt-get install --download-only`
- These are **distro-specific** and cannot be mixed

#### 2. Package Names
Some packages have different names:
| Purpose | Fedora/RHEL | Ubuntu |
|---------|-------------|---------|
| Python headers | `python3-devel` | `python3-dev` |
| ShellCheck | `ShellCheck` | `shellcheck` |
| Process utils | `procps-ng` | `procps` |
| XZ utils | `xz` | `xz-utils` |

### What is Portable (Same Across Distros)

#### 1. CLI Tool Binaries
All downloaded from GitHub/GitLab as static binaries:
- Single Go/Rust binaries: starship, fzf, bat, eza, ripgrep, fd, yazi, lazygit, delta, uv, glab, k9s, lazydocker, glow
- AppImage: nvim
- Static archives: helm, oc, fastfetch

**These work on ANY Linux x86_64 system** (Fedora, UBI9, Ubuntu, etc.)

#### 2. nvim Data (`nvim-data.tar.gz`)
Contains:
- **LazyVim plugins** (`~/.local/share/nvim/lazy/`): Pure Lua code, portable
- **Mason packages** (`~/.local/share/nvim/mason/`): Pre-compiled x86_64 binaries
- **Treesitter parsers** (`~/.local/share/nvim/site/parser/`): Compiled .so files for x86_64
- **Mason registries** (`~/.local/share/nvim/mason/registries/`): JSON data files

**All of these are architecture-specific (x86_64), NOT distro-specific.**

#### 3. Zsh Plugins
Cloned git repos, pure shell scripts - work everywhere

---

## ⚠️ Mason Portability Warning

While most Mason packages are portable, **Python-based LSPs** create virtual environments:

```
~/.local/share/nvim/mason/packages/pylsp/venv/bin/python
```

These venvs contain **absolute paths** to the Python interpreter. When moved to a different system:
- If the path doesn't exist → Mason will reinstall on first nvim launch
- Or: Use `:MasonToolsInstallSync` to reinstall all packages

**Solutions:**
1. **Regenerate on target** (recommended for airgap):
   ```bash
   nvim --headless -c "MasonToolsInstallSync" -c "qa"
   ```

2. **Use the Docker-based generator** per-distro:
   ```bash
   # Generate on Fedora
   bash airgap/docker-prep-nvim.sh fedora
   
   # Generate on UBI9  
   bash airgap/docker-prep-nvim.sh ubi9
   
   # Generate on Ubuntu
   bash airgap/docker-prep-nvim.sh ubuntu
   ```

---

## Recommended Strategy

### For Single Distro Deployment

If you're only deploying to **one distro** (e.g., UBI9 for Run:ai):

```bash
# 1. Build bundle for that specific distro
bash airgap/bundle.sh  # Downloads RPMs (auto-detected)

# 2. Generate nvim data using Docker
bash airgap/docker-prep-nvim.sh ubi9

# 3. Both are now in airgap/cache/
ls -lh airgap/cache/
# devenv-bundle-20260226.tar.gz  (UBI9 RPMs)
# nvim-data.tar.gz               (UBI9-optimized)

# 4. Deploy
bash airgap/deploy.sh --offline
```

### For Multi-Distro Deployment

If you need bundles for **multiple distros**:

```bash
# Build separate bundles for each distro
mkdir -p bundles/{fedora,ubi9,ubuntu}

# Fedora
bash airgap/bundle.sh
mv airgap/devenv-bundle-*.tar.gz bundles/fedora/
bash airgap/docker-prep-nvim.sh fedora
mv airgap/cache/nvim-data.tar.gz bundles/fedora/

# UBI9 (on UBI9 machine or using --distro flag)
# ...similar process

# Ubuntu (on Ubuntu machine)
# ...similar process
```

**Note**: The nvim-data is largely interchangeable, but generating per-distro ensures Python venvs have correct paths.

---

## Quick Reference: Bundle Contents

### devenv-bundle-YYYYMMDD.tar.gz Structure

```
devenv-bundle-YYYYMMDD/
├── cache/
│   ├── rpms/           # Fedora/UBI9: .rpm files
│   │   ├── zsh-*.rpm
│   │   ├── tmux-*.rpm
│   │   └── ...
│   ├── debs/           # Ubuntu: .deb files (if built on Ubuntu)
│   ├── wheels/         # Python tool wheels (optional)
│   ├── starship.tar.gz # CLI tool binaries
│   ├── nvim.appimage
│   ├── k9s.tar.gz
│   └── ...
├── airgap/
│   ├── bundle.sh
│   ├── deploy.sh
│   └── ...
└── versions.lock
```

### nvim-data.tar.gz Structure

```
$HOME/.local/share/nvim/
├── lazy/              # LazyVim plugins (portable)
├── mason/             # LSPs, formatters (mostly portable)
│   ├── bin/
│   ├── packages/
│   └── registries/
└── site/
    └── parser/        # Treesitter parsers (portable)
```

---

## Testing Portability

To verify nvim data works on a different distro:

```bash
# On target machine (different distro)
tar -xzf nvim-data.tar.gz -C $HOME
nvim --headless -c "checkhealth" -c "qa" 2>&1 | head -20
```

Look for:
- ✓ LazyVim loads without errors
- ✓ Mason packages found
- ⚠️ Python venv paths (may show warnings)

If Mason packages fail, run:
```bash
nvim --headless -c "MasonToolsInstallSync" -c "qa"
```

---

## Summary

| Question | Answer |
|----------|--------|
| Do I need separate nvim-data per distro? | **No**, but recommended for Python LSPs |
| Can I use Fedora bundle on UBI9? | **Yes**, but system packages (RPMs) only work on RHEL-based |
| Can I use Fedora nvim-data on Ubuntu? | **Yes**, works fine |
| What's the safest approach? | Build per-distro using `docker-prep-nvim.sh` |
