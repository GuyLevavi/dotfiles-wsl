# CI nvim-data Build Issues

## Problem

The CI workflow (`ci.yml`) runs `airgap/prep-ubuntu-nvim.sh` to build nvim-data with all plugins. The script fails at the lazy.nvim plugin sync step because LazyVim commands aren't available in headless mode.

## Root Cause

When running `nvim --headless`, the nvim config (`.config/nvim/`) isn't being loaded properly. LazyVim's plugin system and commands (`Lazy sync`, `MasonToolsInstallSync`, etc.) are not available because:

1. The nvim is launched without loading the user config
2. The lazy.nvim plugin needs to be bootstrapped before commands work

## Attempts Made

### Attempt 1: Basic nvim --headless
```bash
nvim --headless -c "MasonToolsInstallSync" -c "qa"
```
**Result:** Failed - `E492: Not an editor command: MasonToolsInstallSync`

### Attempt 2: Add lazy.nvim to runtimepath
```bash
nvim --headless -c "set runtimepath+=${XDG_DATA_HOME}/nvim/lazy/lazy.nvim" -c "lua require('lazy').sync({wait=true})"
```
**Result:** Failed - `module 'lazy' not found` - lazy.nvim still not loading properly

### Attempt 3: Source lazy.nvim bootstrap
```bash
nvim --headless -c "source ${XDG_DATA_HOME}/nvim/lazy/lazy.nvim/bootstrap.lua" ...
```
**Result:** Failed - wrong file path, bootstrap.lua doesn't work as expected

### Attempt 4: Use -u NONE with runtimepath
```bash
nvim --headless -u NONE --cmd "set runtimepath+=..." -c "lua require('lazy')..."
```
**Result:** Failed - lazy.nvim requires nvim to be fully initialized

### Attempt 5: Use Lazy! command (without bang)
```bash
nvim --headless "+Lazy! sync" +qa
```
**Result:** Failed - `E492: Not an editor command: Lazy! sync`

### Attempt 6: Use Lazy sync (with space)
```bash
nvim --headless -c "sleep 30" -c "Lazy sync" -c "qa"
```
**Result:** Failed - `E492: Not an editor command: Lazy sync`

## What's Working

- Cloning dotfiles and stowing nvim config works
- Cloning lazy.nvim bootstrap works  
- Installing nvim, rust, tree-sitter-cli works

## Possible Solutions

### Solution 1: Use proper nvim init with eventignore

The key insight is that LazyVim normally loads via `init.lua` which sets up lazy.nvim. We need to:

```bash
nvim --headless \
    -c "set eventignore=all" \
    -c "source ~/.config/nvim/init.lua" \
    -c "lua require('lazy').sync({wait=true})" \
    -c "qa"
```

Or use the `-E` flag for improved ex mode:
```bash
nvim --headless -E -s -c "Lazy sync" -c "qa"
```

### Solution 2: Use nvim startup with -c flag properly

Try launching nvim normally (not headless) but in Ex mode:
```bash
nvim -es -c "Lazy sync" -c "qa"
```

### Solution 3: Install a pre-built nvim-data tarball

Instead of building in CI, generate nvim-data locally and include it in the bundle. The local build works - the issue is only CI.

### Solution 4: Fix the init.lua loading

Ensure the stowed nvim config is loaded properly. The stow creates `.config/nvim` but it might not be found:

```bash
nvim --cmd "set runtimepath+=~/.config/nvim" --headless -c "Lazy sync" -c "qa"
```

### Solution 5: Use LazyVim's CLI tool (if available)

Check if lazyvim has a CLI:
```bash
# Not sure if this exists
lazyvim sync
```

## Files Involved

- `.github/workflows/ci.yml` - CI workflow that calls prep-ubuntu-nvim.sh
- `airgap/prep-ubuntu-nvim.sh` - Script that builds nvim-data (currently failing)
- `nvim/.config/nvim/` - The nvim config being stowed

## CI Environment Details

- Runs in Docker container: `ubuntu:24.04`
- User: `testuser` (created in script)
- HOME: `/home/testuser`
- nvim config stowed to: `/home/testuser/.config/nvim/`
- lazy.nvim cloned to: `/home/testuser/.local/share/nvim/lazy/lazy.nvim`

## Current State

The script reaches this point:
```
✓ lazy.nvim ready
==> Syncing lazy plugins (this may take a few minutes)...
Error detected while processing command line:
E492: Not an editor command: Lazy sync
✓ Lazy plugins: 1
! mason-tool-installer.nvim NOT found!
```

Only 1 plugin (lazy.nvim itself) is found because the plugin sync never runs.

## Next Steps for Future Agent

1. Debug why LazyVim commands aren't available - check if `.config/nvim/init.lua` is being sourced
2. Try using `-E` (improved Ex mode) or `-e` flags for nvim
3. Consider building nvim-data locally instead of in CI
4. Check if there's a LazyVim-specific way to run in headless mode
