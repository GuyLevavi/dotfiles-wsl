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
| WSL (Ghostty/WezTerm) | `WSL_DISTRO_NAME` set | **win32yank.exe** (preferred) → fallback `clip.exe` |
| Docker / Linux desktop | `/.dockerenv` exists or `$DISPLAY` set | OSC52 terminal escape sequences |
| Headless (no DISPLAY, not WSL) | Fallback | Internal nvim clipboard only; shows notification |

### WSL Clipboard — win32yank (Critical)

`clip.exe` **only copies, it cannot paste**. `win32yank.exe` handles both directions and is faster.

**Critical**: `win32yank.exe` MUST live on the Windows filesystem, NOT copied into the WSL rootfs. Use a symlink:

```bash
# Option A: if Neovim is installed on Windows (recommended)
ln -s "/mnt/c/Program Files/Neovim/bin/win32yank.exe" ~/.local/bin/win32yank.exe

# Option B: install standalone (run in Windows PowerShell/CMD):
winget install win32yank
# Then find installation path and symlink it
```

`options.lua` priority for WSL:
1. `win32yank.exe` if `vim.fn.executable('win32yank.exe') == 1`
2. `clip.exe` / `powershell.exe` as fallback

**`cache_enabled = 0` required** — `cache_enabled = 1` causes ~10 second hang on every yank.

### Linux Desktop / Docker Clipboard

OSC52 escape sequences work through the terminal emulator. Supported by: WezTerm, Ghostty, Alacritty, Windows Terminal, iTerm2.

If OSC52 isn't working inside `docker exec`, try running the container with `-e TERM=xterm-256color` or check if your terminal emulator passes OSC52 through docker.

**Keymap behavior:**
- `y`, `yy`, `Y` → yank to `+` register (system clipboard)
- `dd`, `x`, `d` → delete to unnamed register (internal only)
- Keymaps are only set when a clipboard provider is available.

---

## Mason Packages — Only These 3 Are Valid

Only these Mason packages should be in `ensure_installed`. **Any others cause startup errors.**

```lua
ensure_installed = { "basedpyright", "ruff", "debugpy" }
```

Removed (caused dangling errors): `pyright`, `docker-compose`, `lua_ls`, `marksman`.
If `lua_ls` or `marksman` are needed later, add them back deliberately with full config.

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
