# GOTCHAS.md — WSL, Windows, Stow & Deploy Quirks

Referenced from [AGENTS.md](../AGENTS.md). Read this before touching bootstrap, deploy, stow, or any WSL↔Windows interaction.

---

## WSL from Windows (Git Bash)

| Problem | Fix |
|---------|-----|
| `/usr/bin/env` mangled to `C:/Program Files/Git/usr/bin/env` | Use `wsl.exe -d FedoraLinux-43 -u gl -- zsh -c 'command'` pattern |
| `$HOME` not expanding in `wsl -- bash -c '...'` | PowerShell eats it — set explicitly via `getent passwd` |
| PowerShell pipe to WSL adds UTF-8 BOM | Use `Write-WslScript` pattern: `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)` |
| `wsl --list --quiet` outputs UTF-16 with null bytes | Strip with `-replace "\`0", ""` |
| Multiline scripts don't work via pipe | Write to a file inside WSL first, then execute |

**Preferred WSL invocation pattern:**
```powershell
wsl.exe -d FedoraLinux-43 -u gl -- zsh -c 'command here'
```

---

## WSL Imported Distros

- `$HOME` may be `/root` in non-login bash sessions — always set explicitly via `getent passwd` if needed.
- `/tmp` gets cleaned by systemd on restart — stow targets must be on persistent paths (e.g. `~/dotfiles`, NOT `/tmp/dotfiles`).
- Firewall uses **nftables**, NOT iptables (Fedora 43 minimal). `test-offline.ps1` uses nftables to block network.

---

## Stow

- Stow may symlink **parent directories**, not individual files. `~/.config/nvim` is a directory symlink, not a tree of file symlinks.
- `test -L ~/.config/nvim/init.lua` → **false** (the symlink is the dir, not the file)
- Always use `test -f ~/.config/nvim/init.lua` → **true**

### Stow Conflicts on Cloned Distros

When deploying to a cloned distro, existing config files from the source distro cause stow conflicts. `04-stow-dotfiles.sh` has `backup_conflicts()` but it's better to pre-clean in test scenarios. Must reset ALL config paths including:
- `.codex/`
- `.config/opencode/`
- `.config/containers/`
- `.config/nvim/`
- etc.

---

## deploy.sh Temp Dir Permissions

`mktemp -d` creates `0700` dirs owned by root. When `run_as_user` runs scripts as the target user, they can't read root-owned temp dirs.

**Fix**: Always `chmod 755` temp dirs and `chmod -R a+rX` extracted contents after creation.

---

## WezTerm Config

`wezterm/.wezterm.lua` in the repo is the **reference copy only**. The actual Windows-side config lives at `C:\Users\guyle\.wezterm.lua` and must be **manually synced**. It is NOT managed by stow.

---

## Clipboard in Different Contexts

The clipboard provider varies by runtime context — `options.lua` auto-detects:

| Context | Detection | Provider |
|---------|-----------|----------|
| WSL | `WSL_DISTRO_NAME` set | win32yank.exe → xclip → full-path clip.exe (priority order) |
| Linux desktop (X11) | `$DISPLAY` set, not WSL | xclip |
| Linux desktop (Wayland) | `$WAYLAND_DISPLAY` set | wl-copy / wl-paste |
| Docker / headless | fallback | OSC52 terminal escape sequences |

### WSL Clipboard — Priority Order

`/etc/wsl.conf` has `appendWindowsPath=false`, so Windows executables like `clip.exe`
are **not in `$PATH`** (bare `clip.exe` fails). The full path must be used.

`options.lua` detection order for WSL:

1. **`win32yank.exe`** (best — bidirectional, fast). Needs manual setup:
   ```bash
   ln -s "/mnt/c/Program Files/Neovim/bin/win32yank.exe" ~/.local/bin/win32yank.exe
   # or: winget install win32yank  (run in Windows PowerShell)
   ```
   `win32yank.exe` MUST live on the Windows filesystem, NOT copied into the WSL rootfs.

2. **`xclip`** (good — bidirectional via WSLg X11). WSLg sets `DISPLAY=:0` so xclip
   works out of the box once installed. This is the **current active provider** on
   the Debian WSL setup after running:
   ```bash
   sudo apt install xclip
   ```

3. **`/mnt/c/Windows/System32/clip.exe`** (last resort — copy-only, paste uses
   `powershell.exe`). Full path required because `appendWindowsPath=false`.

4. **`vim.notify` warning** if no provider found.

**`cache_enabled = 0` required for win32yank and clip.exe** — `cache_enabled = 1` causes ~10 second hang on every yank.

### Linux Desktop / Docker Clipboard

OSC52 escape sequences work through the terminal emulator. Supported by: WezTerm, Ghostty, Alacritty, Windows Terminal, iTerm2.

If OSC52 isn't working inside `docker exec`, try running the container with `-e TERM=xterm-256color` or check if your terminal emulator passes OSC52 through docker.

**Keymap behavior:**
- `y`, `yy`, `Y` → yank to `+` register (system clipboard)
- `dd`, `x`, `d` → delete to unnamed register (internal only)
- Keymaps are only set when a clipboard provider is available.

---

## Mason Packages — Safe List

### Airgap branch (`main`)

Only these 3 packages are safe. Others cause dangling-package errors because Mason
can't download them at runtime:

```lua
ensure_installed = { "basedpyright", "ruff", "debugpy" }
```

### Online branch

The full 11-package list in `mason-tools.lua` is safe. Mason downloads any missing
packages on first startup.

---

## basedpyright + pyright Conflict

**Symptom**: Mason startup error trying to install `pyright`. `gD` and `<leader>sP`
(document symbols) fail with "textDocument method not supported".

**Root cause**: LazyVim's `lang.python` extra registers both `"pyright"` and
`"basedpyright"` in `opts.servers` (with `enabled=false` on the inactive one) as a
housekeeping step. The side-effect is that LazyVim's LSP init tells mason-lspconfig
to `ensure_installed` both. Two LSPs attach to the same buffer and the wrong one
answers `gD`/symbol requests.

**Fix** (already applied in `python.lua`):
```lua
{
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers["pyright"] = nil    -- remove so Mason never installs it
    opts.servers["ruff_lsp"] = nil   -- old ruff LSP name, superseded by "ruff"
  end,
},
```

**Note**: `automatic_installation` was removed in mason-lspconfig v2 (May 2025).
LazyVim handles `automatic_enable` correctly — no override needed.

---

## DAP / Mason Path Resolution

`get_install_path()` can fail silently. Always:
1. Wrap Mason registry calls in `pcall()`
2. Check multiple Mason paths: `/venv/bin/python`, `/bin/python`, etc.
3. Verify the module is importable: `python -c "import debugpy"`
4. Fallback to system Python if it has debugpy
5. Wrap `dap-python.setup()` in `pcall()` — never let it hard-fail on startup

Debug inside container:
```bash
find ~/.local/share/nvim/mason -name "python" -o -name "debugpy" 2>/dev/null
```

---

## blink.cmp — libblinkcmp_fuzzy

blink.cmp ships a precompiled Rust `.so` library. It must be present in the nvim-data tarball and must match the target glibc version (Ubuntu 24.04).

If missing: check `find ~/.local/share/nvim/lazy/blink.cmp -name "*.so"`. If the `.so` is absent, blink.cmp needs to be compiled from source in the Dockerfile rather than using a prebuilt binary.

---

## yazi --version

yazi produces no output from `--version` in non-TTY contexts. Verify installation with `test -x` instead of running the binary.

---

## OpenCode Theme Name

Must be `"tokyonight"` — no hyphen. `"tokyo-night"` silently falls back to black. This applies to OpenCode config only; other tools may use different conventions.

---

## Marimo Port Binding

Marimo defaults to binding `127.0.0.1` inside the container, making it unreachable from the host even with port mapping.

Always start with explicit host:
```bash
marimo tutorial intro --host 0.0.0.0 --port 2718
marimo edit --host 0.0.0.0 --port 2718
```

Dockerfile exposes `2718` and `8888`. Run container with `-p 2718:2718`.

---

## Btop Locale

Btop requires a UTF-8 locale. Dockerfile sets:
```dockerfile
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
```

Without this, btop starts with locale warnings (non-fatal but noisy).

---

## Tmux

- `detach-on-destroy off` — keeps tmux alive when last window closes
- History limit: 1,000,000 lines
- Copy mode clipboard: auto-detects WSL (`clip.exe`), xclip, wl-copy, or falls back to internal
- Zoom indicator `[Z]` shown in window status bar when a pane is zoomed
- TPM plugins (sessionx, floax, resurrect) must be installed at Docker build time — never `prefix + I` in airgap

### omerxx-inspired Tmux Plugins (pre-install at build time)
- `omerxx/tmux-sessionx` — fzf session manager with preview (`prefix + o`)
- `omerxx/tmux-floax` — floating pane overlay (`prefix + p`)
- `tmux-plugins/tmux-resurrect` + `tmux-continuum` — session persistence
