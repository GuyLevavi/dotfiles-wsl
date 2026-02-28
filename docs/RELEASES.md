# RELEASES.md — Versioning, Bundles & Release Process

Referenced from [AGENTS.md](../AGENTS.md).

---

## Release Assets (per GitHub release tag)

Each tag should produce:

| Asset | Description | How generated |
|-------|-------------|---------------|
| `devenv-bundle-YYYYMMDD.tar.gz` | Full offline WSL bundle (system debs + tool binaries) | `airgap/bundle.sh` |
| `nvim-data-YYYYMMDD.tar.gz` | Nvim plugins + Mason + parsers only | See §Nvim Data Snapshot |
| `versions.lock` | Pinned tool versions | Written by `bundle.sh` |
| `nvim-plugin-manifest.json` | Plugin name → commit SHA | See §Plugin Manifest |

---

## Current Bundle

**Latest**: `devenv-bundle-20260228.tar.gz` (516MB)
**GitHub Release**: v1.8.1
**URL**: https://github.com/GuyLevavi/dotfiles-wsl/releases/tag/v1.8.1

Full history: `airgap/BUNDLE_HISTORY.md`

---

## Plugin Manifest

Generate during Docker build to get a diffable record of which plugin is at which commit:

```bash
find ~/.local/share/nvim/lazy -maxdepth 1 -mindepth 1 -type d | while read dir; do
  name=$(basename "$dir")
  sha=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "unknown")
  printf '"%s": "%s"\n' "$name" "$sha"
done | jq -s 'add' > nvim-plugin-manifest.json
```

Attach `nvim-plugin-manifest.json` to the GitHub release. `git diff` between two release manifests shows exactly which plugins changed commits.

---

## Nvim Data Snapshot

To create a standalone nvim data tarball (useful for faster re-deploys without full image rebuild):

```bash
# Inside the built Docker container:
tar czf nvim-data-$(date +%Y%m%d).tar.gz \
  -C "$HOME" \
  .local/share/nvim/lazy \
  .local/share/nvim/mason \
  .local/share/nvim/site/parser
```

This can be extracted into a fresh environment to skip the plugin install step.

---

## Tagging & Release Process

```bash
# 1. Ensure all changes are merged to main
# 2. Build and test the Docker image
docker build -t airgap-dev:latest .
docker run --network none airgap-dev:latest zsh -c 'nvim --version && echo OK'

# 3. Build the airgap bundle (on network-connected machine)
cd airgap && ./bundle.sh

# 4. Generate plugin manifest (from inside container)
docker run airgap-dev:latest bash -c '<manifest script above>'

# 5. Tag
git tag -a vX.Y.Z -m "Release vX.Y.Z: <summary>"
git push origin vX.Y.Z

# 6. Create GitHub release with assets
"C:\Program Files\GitHub CLI\gh.exe" release create vX.Y.Z \
  airgap/devenv-bundle-YYYYMMDD.tar.gz \
  airgap/cache/versions.lock \
  nvim-plugin-manifest.json \
  --title "vX.Y.Z" \
  --notes "<changelog>"
```

---

## Version Tracking Philosophy

- **Tool versions**: `versions.lock` is the source of truth. Commit it with every bundle build.
- **Plugin versions**: `nvim-plugin-manifest.json` per release — not committed to repo (too noisy), attached to GitHub releases.
- **System packages**: Not pinned (apt installs latest at build time). Acceptable — system packages are stable; tool binaries are what matters.
- **Python packages**: Managed by `uv` per project — not part of the base image.

---

## GHCR (GitHub Container Registry)

Push the Docker image to GHCR so RunAI can pull without a bundle:

```bash
# Authenticate (needs write:packages token)
echo $GITHUB_TOKEN | docker login ghcr.io -u GuyLevavi --password-stdin

# Tag and push
docker tag airgap-dev:latest ghcr.io/guylevavi/airgap-dev:latest
docker tag airgap-dev:latest ghcr.io/guylevavi/airgap-dev:vX.Y.Z
docker push ghcr.io/guylevavi/airgap-dev:latest
docker push ghcr.io/guylevavi/airgap-dev:vX.Y.Z
```

Once on GHCR, RunAI jobs can reference `ghcr.io/guylevavi/airgap-dev:latest` directly — no manual bundle transfer needed.

---

## Nix AppImage Strategy (Future)

**Status**: Research complete, not implemented. See TODO.md I1.

### What It Solves

A single `nvim.AppImage` (~200MB) containing neovim + all plugins + all LSPs + all parsers. Copy to any Linux machine (`chmod +x nvim.AppImage && ./nvim.AppImage`) — no installation, no Docker, no stow.

### How It Works (iofq/nvim.nix pattern)

1. Nix flake declares all plugins as Nix packages (pinned by hash in `flake.lock`)
2. Build produces a neovim binary with plugins pre-loaded into the Nix store
3. GitHub Actions CI bundles the Nix closure into an AppImage
4. `lazy.nvim` is still used for Lua module loading and lazy-loading — the config keeps working as normal LazyVim Lua

The trick: in `mkNeovim.nix`, a `lazy_opts` variable is prepended to `init.lua` pointing lazy.nvim to the Nix-installed plugin paths instead of GitHub. If `lazy_opts` is not set, lazy bootstraps normally for non-Nix usage.

### Performance Tip

Extract the AppImage instead of running directly:
```bash
./nvim.AppImage --appimage-extract
# Run squashfs-root/AppRun instead — avoids re-extraction on every launch
```

### References

- https://github.com/iofq/nvim.nix — reference implementation
- https://github.com/nix-community/kickstart-nix.nvim — base template
- https://github.com/nix-community/nixvim — alternative (fully declarative, loses lazy.nvim)

### Why iofq Over nixvim

`nixvim` replaces lazy.nvim with Nix-native loading. That means rewriting all plugin specs in Nix. The `iofq` pattern keeps your `lua/plugins/*.lua` files intact — Nix just handles downloading and the AppImage bundling.

### Migration Path (when ready)

1. Install Nix (doesn't require NixOS — works on Ubuntu/WSL)
2. Fork `iofq/nvim.nix` or start from `kickstart-nix.nvim`
3. Declare plugins in `flake.nix` (mirrors what's currently in `lazy.lua`)
4. Run `nix build` → produces `result/bin/nvim`
5. Enable GitHub Actions CI workflow to build AppImage on push
6. AppImage becomes a release asset alongside the bundle tarball
