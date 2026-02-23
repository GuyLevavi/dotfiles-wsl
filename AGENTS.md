# AGENTS.md — Project Context for AI Assistants

## What This Is

Dotfiles repo for a WSL2-based Python CV/DL development environment. Targets
airgapped networks — everything must work offline after initial bundle creation.

Published at: https://github.com/GuyLevavi/dotfiles-wsl

## Architecture

### Stow-Centric Layout

Each directory at the repo root is a GNU Stow package mirroring `$HOME`:

```
zsh/.zshrc            → ~/.zshrc
nvim/.config/nvim/    → ~/.config/nvim/
starship/.config/     → ~/.config/starship.toml
tmux/.config/tmux/    → ~/.config/tmux/
git/.gitconfig        → ~/.gitconfig
podman/.config/       → ~/.config/containers/
opencode/.config/     → ~/.config/opencode/
codex/.codex/         → ~/.codex/
```

Stow may symlink parent directories (e.g. `~/.config/nvim` is a directory
symlink, not individual file symlinks). This means `test -L ~/.config/nvim/init.lua`
returns false — use `test -f` instead.

### Bootstrap Pipeline

Six scripts in `bootstrap/`, run in order:

| Script | Runs as | Purpose |
|--------|---------|---------|
| `00-install-fedora-wsl.ps1` | Windows/PowerShell | Installs Fedora 43 WSL |
| `01-create-user.sh` | root | Creates user `gl` with wheel group |
| `02-install-packages.sh` | root | DNF packages (`--minimal` skips build deps) |
| `03-install-tools.sh` | user | Downloads/installs 18 CLI tools to `~/.local/bin` |
| `04-stow-dotfiles.sh` | user | Stow all packages, backs up conflicts |
| `05-setup-shell.sh` | root | Sets zsh as default shell |

### Airgap Pipeline

Three components:

1. **`airgap/bundle.sh`** — Downloads tool binaries + zsh plugins into
   `airgap/cache/`, creates `devenv-bundle-YYYYMMDD.tar.gz`. Uses
   `versions.lock` to pin versions.

2. **`airgap/deploy.sh`** — Extracts bundle, derives repo location from its
   own `BASH_SOURCE`, symlinks extracted cache into repo, runs bootstrap
   scripts 02-05 with `--offline` flag.

3. **`test-offline.ps1`** — End-to-end test: exports WSL, imports clone,
    blocks network via nftables, deploys bundle, verifies 27 checks
    (18 tools + 9 configs).

## Environment

- **WSL distro**: FedoraLinux-43
- **User**: `gl` (uid 1000, wheel group)
- **Shell**: zsh + zinit + starship prompt
- **Editor**: Neovim 0.11+ with LazyVim
- **Terminal**: WezTerm (Windows-side, NOT symlinked via stow)
- **Theme**: Tokyo Night everywhere
- **Font**: JetBrainsMono Nerd Font

## Critical Conventions

### Colorblind Accessibility

User has deuteranopia. Never use red for status/errors. Use:
- Orange `#ff9e64` for errors/warnings
- Blue for info
- Magenta for accents

### LazyVim Extras Over Manual Config

Use LazyExtras for LSP/tool setup. Extras are imported in `nvim/.config/nvim/lua/config/lazy.lua`
(lines ~61-84). Do NOT duplicate what LazyExtras provides. The `lazyvim.json`
extras array is empty — the imports in `lazy.lua` are what enables them.

### Minimal Configs

Remove bloat. If the default is good, don't override it. Configs should be
minimal and commented so a vim beginner can understand them.

### Version Pinning

`airgap/cache/versions.lock` pins all tool versions. `bundle.sh` writes it,
`03-install-tools.sh --offline` reads it. Both must agree on cache filenames:

```
starship.tar.gz, zoxide.tar.gz, fzf.tar.gz, bat.tar.gz, eza.tar.gz,
ripgrep.tar.gz, fd.tar.gz, yazi.zip, lazygit.tar.gz, uv.tar.gz,
glab.tar.gz, jf, delta.tar.gz, nvim.appimage, helm.tar.gz, oc.tar.gz,
fastfetch.tar.gz, mc
```

### GitLab API for glab

glab is hosted on GitLab, not GitHub. Use `gl_latest()` function (GitLab API
at `gitlab.com/api/v4/projects/{url-encoded}/releases`) instead of `gh_latest()`.

## Gotchas

### WSL from Windows (Git Bash)

When calling WSL commands from Windows Git Bash:
- `/usr/bin/env` gets mangled to `C:/Program Files/Git/usr/bin/env`
- `$HOME` in `wsl -- bash -c '...'` may not expand (PowerShell eats it)
- Use `wsl.exe -d FedoraLinux-43 -u gl -- zsh -c 'command'` pattern
- For multiline scripts, write to a file inside WSL first, then execute
- PowerShell pipe to WSL adds UTF-8 BOM — use `Write-WslScript` pattern
  (write via `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`)
- `wsl --list --quiet` outputs UTF-16 with null bytes — strip with
  `-replace "\`0", ""`

### WSL Imported Distros

- `$HOME` may be `/root` in non-login bash sessions — always set explicitly
  via `getent passwd` if needed
- `/tmp` gets cleaned by systemd on restart — stow targets must be on
  persistent paths (e.g. `~/dotfiles`, NOT `/tmp/dotfiles`)
- Firewall uses nftables, NOT iptables (Fedora 43 minimal)

### Stow Conflicts

When deploying to a cloned distro, existing config files from the source
distro cause stow conflicts. The test script must reset ALL config paths
including `.codex/`, `.config/opencode/`, `.config/containers/`, etc.
The `04-stow-dotfiles.sh` has `backup_conflicts()` but it's better to
pre-clean in test scenarios.

### deploy.sh Temp Dir Permissions

`mktemp -d` creates 0700 dirs owned by root. When `run_as_user` runs
scripts as the target user, they can't read root-owned temp dirs. Always
`chmod 755` temp dirs and `chmod -R a+rX` extracted contents.

### WezTerm Config

`wezterm/.wezterm.lua` in the repo is the reference copy. The actual
Windows-side config is at `C:\Users\guyle\.wezterm.lua` and must be
manually synced — it is NOT managed by stow.

### OpenCode Theme

Must be `"tokyonight"` (no hyphen). `"tokyo-night"` causes black fallback.

### yazi --version

yazi produces no output from `--version` in non-TTY contexts. Verify with
`test -x` instead of running the command.

## GitHub CLI

GitHub CLI is at `"C:\Program Files\GitHub CLI\gh.exe"` — not in PATH.
Use full path for `gh` commands.

## Workflow

- Work on feature branches, create PRs (not direct commits to main)
- User explicitly asks for commits — don't commit proactively
- Install latest versions of tools by default
- After changes, user wants PR created and pushed
