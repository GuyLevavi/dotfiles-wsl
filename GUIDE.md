# Terminal Development Environment — Complete Guide

> This guide explains every tool installed in your development environment,
> what it does, why it's there, and how to use it. It assumes you're coming
> from a Windows / GUI background with limited Linux experience.

---

## Table of Contents

1. [Foundational Concepts](#1-foundational-concepts)
2. [The Big Picture — How Everything Fits Together](#2-the-big-picture)
3. [WezTerm — Your Terminal Emulator](#3-wezterm)
4. [Zsh — Your Shell](#4-zsh)
5. [Zinit — Shell Plugin Manager](#5-zinit)
6. [Starship — Your Prompt](#6-starship)
7. [tmux — Terminal Multiplexer](#7-tmux)
8. [Neovim + LazyVim — Your Code Editor](#8-neovim--lazyvim)
9. [Git Tools (lazygit, delta, glab)](#9-git-tools)
10. [File Navigation (yazi, zoxide, fzf)](#10-file-navigation)
11. [Better Unix Commands (bat, eza, fd, ripgrep)](#11-better-unix-commands)
12. [Python Toolchain (uv, marimo)](#12-python-toolchain)
13. [Containers (podman)](#13-containers)
14. [Dotfile Management (GNU Stow)](#14-dotfile-management)
15. [Tokyo Night — Color Scheme](#15-tokyo-night)
16. [Your Aliases Cheat Sheet](#16-aliases-cheat-sheet)
17. [Daily Workflow Examples](#17-daily-workflow-examples)
18. [Troubleshooting](#18-troubleshooting)

---

## 1. Foundational Concepts

Before diving into tools, let's clarify some concepts that will come up
repeatedly.

### Terminal Emulator vs Shell

This is the most important distinction:

| | Terminal Emulator (WezTerm) | Shell (Zsh) |
|---|---|---|
| **What is it** | A GUI window on your screen | A program running *inside* that window |
| **What it controls** | Font, colors, transparency, tabs, key shortcuts | Command execution, aliases, scripting, PATH |
| **Analogy** | A web browser window | The website loaded inside it |

You type `ls` and press Enter. **Zsh** (the shell) interprets that command
and runs the `ls` program. The output text flows back to **WezTerm** (the
terminal emulator), which renders it in your chosen font and colors.

You can swap either independently — run Zsh in a different terminal, or run
Bash in WezTerm.

### What Are Dotfiles?

Any file or directory whose name starts with `.` (a dot) is **hidden** on
Linux. The `ls` command won't show them unless you use `ls -a`.

Why hidden? It's a Unix convention to keep config files out of normal
directory listings. Your home directory might have dozens of them:

```
~/.zshrc          ← Zsh shell configuration
~/.gitconfig      ← Git settings
~/.config/nvim/   ← Neovim configuration
~/.config/tmux/   ← Tmux configuration
```

The term **"dotfiles"** collectively refers to your personal configuration
files. Developers often store these in a Git repo so they can sync their
setup across machines.

### What Are Symlinks (Symbolic Links)?

**Windows analogy:** A symlink is like a Windows shortcut, but it works at
the filesystem level — every program sees it as if it *is* the real file.

```bash
# Create a symlink
ln -s /path/to/real/file /path/to/link

# Example:
ln -s ~/dotfiles/zsh/.zshrc ~/.zshrc
```

Now `~/.zshrc` is a symlink that points to `~/dotfiles/zsh/.zshrc`. When
any program reads `~/.zshrc`, it transparently reads the real file inside
your dotfiles folder.

**Key differences from Windows shortcuts:**
- A `.lnk` shortcut only works in Windows Explorer
- A symlink is transparent to *all* programs — `cat`, `vim`, Python, everything
- Delete the symlink → original file is safe
- Delete the original → symlink becomes "broken" (dangling)

You can see symlinks with `ls -la`:
```
lrwxrwxrwx  1 gl gl  75 Feb 20 19:54 .zshrc -> ../../dotfiles/zsh/.zshrc
```
The `l` at the start and the `->` arrow show it's a symlink.

### What Is PATH?

`PATH` is an environment variable containing a list of directories separated
by colons. When you type a command (like `git`), your shell searches these
directories **in order** to find the program:

```bash
echo $PATH
# /home/gl/.local/bin:/usr/local/bin:/usr/bin:/bin
```

If you install a tool and the shell says "command not found", it usually
means the tool isn't in any PATH directory. That's why `~/.local/bin` is
important — it's the standard place for user-installed programs that don't
require admin privileges.

### What Is XDG?

The XDG Base Directory Specification is a Linux standard that says:
- Config files go in `~/.config/`
- Data files go in `~/.local/share/`
- Cache files go in `~/.cache/`
- User executables go in `~/.local/bin/`

Modern tools follow this convention. Older tools (like Git) still use
dotfiles directly in `~` (e.g., `~/.gitconfig`).

---

## 2. The Big Picture

Here's how all the tools relate to each other:

```
┌─────────────────────────────────────────────────┐
│ WezTerm (terminal emulator - runs on Windows)   │
│ Renders text, handles fonts/colors/keybindings  │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ WSL2 / Fedora 43 (Linux environment)    │    │
│  │                                         │    │
│  │  Zsh (shell) + Zinit (plugins)          │    │
│  │  Starship (prompt)                      │    │
│  │                                         │    │
│  │  ┌──── tmux (multiplexer) ────────┐     │    │
│  │  │ ┌─────────┐  ┌──────────────┐  │     │    │
│  │  │ │ Neovim  │  │ shell pane   │  │     │    │
│  │  │ │(editor) │  │ (commands)   │  │     │    │
│  │  │ └─────────┘  └──────────────┘  │     │    │
│  │  │ ┌──────────────────────────────┤     │    │
│  │  │ │ lazygit / yazi / marimo      │     │    │
│  │  │ └──────────────────────────────┘     │    │
│  │  └────────────────────────────────┘     │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

**Layer by layer:**
1. **WezTerm** is the window you see on your screen (runs on Windows)
2. It connects into **WSL2 Fedora** (a Linux environment inside Windows)
3. **Zsh** is the shell that interprets your commands
4. **tmux** lets you split that shell into multiple panes and sessions
5. Inside tmux, you run **Neovim** for editing, **lazygit** for git, etc.

---

## 3. WezTerm

**What:** A GPU-accelerated terminal emulator written in Rust.
**Config:** `~/.wezterm.lua` (on your Windows home directory)

### Why WezTerm?
- Fast GPU rendering (text scrolls smoothly even with huge output)
- Native WSL2 integration (connects directly to your Linux distros)
- Lua configuration (a real programming language, not just key=value)
- Built-in multiplexing (tabs and panes, though we use tmux for this)
- Catppuccin and hundreds of other themes built in

### Key Shortcuts (from your config)

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+W` | Close current pane |
| `Ctrl+Shift+N` | Next tab |
| `Ctrl+Shift+P` | Previous tab |
| `Ctrl+Shift+\|` | Split pane horizontally (side by side) |
| `Ctrl+Shift+-` | Split pane vertically (top/bottom) |
| `Ctrl+Shift+H/J/K/L` | Navigate between panes (vim-style) |
| `Ctrl+Shift+Z` | Zoom/unzoom current pane (fullscreen toggle) |
| `Ctrl+Shift+F` | Search in scrollback |
| `Ctrl+Shift+Space` | Quick select (click-to-copy URLs, paths, etc.) |
| Right-click | Paste from clipboard |

### Tips
- WezTerm reloads its config automatically when you save the file
- If it crashes on launch, try changing `WebGpu` to `OpenGL` in the config
- The `window_background_opacity = 0.95` gives a subtle transparency effect

---

## 4. Zsh

**What:** Z Shell — an interactive command-line shell (like Bash, but better).
**Config:** `~/.zshrc`

### Why Zsh over Bash?
- Much better tab completion (with menus and fuzzy matching)
- Plugin ecosystem (thousands of plugins via zinit/oh-my-zsh)
- Better globbing (e.g., `**/*.py` to find all Python files recursively)
- Spelling correction for typos
- Mostly backward-compatible with Bash

### Key Features in Your Config

**History:** Your shell remembers the last 10,000 commands. Press `↑` to
scroll through them, or `Ctrl+R` to fuzzy-search with fzf.

```bash
# History settings in your .zshrc:
HISTSIZE=10000            # commands kept in memory
SAVEHIST=10000            # commands saved to disk
SHARE_HISTORY             # shared across all open terminals
HIST_IGNORE_ALL_DUPS      # no duplicates
HIST_IGNORE_SPACE         # prefix with space to keep a command out of history
```

**Emacs-style keybindings** (these work in your command line):

| Shortcut | Action |
|---|---|
| `Ctrl+A` | Jump to beginning of line |
| `Ctrl+E` | Jump to end of line |
| `Ctrl+W` | Delete word backward |
| `Ctrl+U` | Delete entire line |
| `Ctrl+K` | Delete from cursor to end |
| `Ctrl+L` | Clear screen |
| `Ctrl+R` | Search command history (via fzf) |
| `Tab` | Autocomplete (with menu selection) |
| `Ctrl+C` | Cancel current command |
| `Ctrl+D` | Exit shell (logout) |

### Useful Shell Features

```bash
# Run the last command with sudo
sudo !!

# Run the last command that started with "git"
!git

# Use the last argument of the previous command
vim !$

# Globbing: find all Python files recursively
ls **/*.py

# Redirect output to a file
command > output.txt       # overwrite
command >> output.txt      # append
command 2>&1 > output.txt  # include errors

# Pipe: send output of one command as input to another
cat file.txt | grep "error" | wc -l
```

---

## 5. Zinit

**What:** A plugin manager for Zsh — an "app store" for shell features.
**Location:** `~/.local/share/zinit/`

### What It Does
Zinit downloads, manages, and loads shell plugins from GitHub. Plugins add
features like syntax highlighting, autosuggestions, and better completions
to your shell.

### Plugins Installed in Your Config

1. **fast-syntax-highlighting** — Colors your commands as you type:
   - Valid commands → green
   - Invalid commands → red
   - Strings → yellow
   - You spot typos *before* pressing Enter

2. **zsh-autosuggestions** — Ghost-text suggestions from your history:
   - As you type, a gray suggestion appears
   - Press `→` (right arrow) to accept the entire suggestion
   - Press `Ctrl+→` to accept one word at a time
   - Keeps typing to narrow down or ignore the suggestion

3. **zsh-completions** — Extra tab-completion definitions for hundreds of tools

### Turbo Mode
Your config uses `wait lucid` — this means plugins load *after* the prompt
appears. Your shell starts instantly, and plugins kick in within
milliseconds. You won't notice the delay.

### Managing Plugins

```bash
zinit update --parallel    # Update all plugins
zinit delete --clean       # Remove unused plugins
zinit report               # Show what each plugin loaded
zinit loaded               # List loaded plugins
```

---

## 6. Starship

**What:** A fast, customizable shell prompt.
**Config:** `~/.config/starship.toml`

### What It Does
The prompt is the text that appears before your cursor. Instead of a plain
`$`, Starship shows useful context:

```
~/Projects/my-ml-project  main ✚1 ?2  v3.12.8  3s
❯
```

This tells you at a glance:
- Current directory: `~/Projects/my-ml-project`
- Git branch: `main`
- Git status: 1 staged change, 2 untracked files
- Python version: 3.12.8 (detected from `pyproject.toml`)
- Last command took 3 seconds

### Intelligence
Starship is context-aware — it only shows modules that are relevant:
- Python version only appears in directories with `.py` files or `pyproject.toml`
- Git info only appears inside Git repos
- Docker context only appears when Docker/Podman is configured
- Command duration only shows for commands > 2 seconds

### Customization
Edit `~/.config/starship.toml` to change what appears in your prompt.
Common tweaks:

```toml
# Change the prompt character
[character]
success_symbol = "[➜](bold green)"

# Disable a module entirely
[nodejs]
disabled = true

# Change format of a module
[python]
format = '[${symbol}${pyenv_prefix}(${version} )(\($virtualenv\) )]($style)'
```

---

## 7. tmux

**What:** A terminal multiplexer — run multiple terminals inside one window,
with persistent sessions that survive disconnects.
**Config:** `~/.config/tmux/tmux.conf`

### Why tmux?
1. **Split your screen** into multiple panes (editor + shell + logs)
2. **Sessions persist** — detach, close WezTerm, come back later, reattach
3. **Remote safety** — if your SSH connection drops, your work continues

### Core Concepts

```
Session "work"
├── Window 1 "editor"
│   ├── Pane 1 (neovim)
│   └── Pane 2 (shell)
└── Window 2 "server"
    └── Pane 1 (running a server)
```

- **Session** = a workspace (you can have several)
- **Window** = like a browser tab within a session
- **Pane** = a split within a window

### The Prefix Key

Almost all tmux shortcuts start with a **prefix key**. Your config sets it
to `Ctrl+A` (the default is `Ctrl+B`, but `Ctrl+A` is easier to reach).

To use a tmux shortcut: press `Ctrl+A`, release, then press the next key.
For example, `Ctrl+A` then `|` splits the window horizontally.

### Essential Shortcuts (Your Config)

**Sessions:**

| Shortcut | Action |
|---|---|
| `Ctrl+A` then `d` | **Detach** from session (it keeps running) |
| `Ctrl+A` then `s` | List and switch sessions |
| `Ctrl+A` then `$` | Rename current session |

**Windows (tabs):**

| Shortcut | Action |
|---|---|
| `Ctrl+A` then `c` | Create new window |
| `Ctrl+A` then `0-9` | Jump to window by number |
| `Ctrl+A` then `n` | Next window |
| `Ctrl+A` then `p` | Previous window |
| `Ctrl+A` then `,` | Rename current window |
| `Ctrl+A` then `&` | Kill current window |

**Panes (splits):**

| Shortcut | Action |
|---|---|
| `Ctrl+A` then `\|` | Split horizontally (side by side) |
| `Ctrl+A` then `-` | Split vertically (top/bottom) |
| `Ctrl+A` then `h/j/k/l` | Move between panes (vim-style) |
| `Ctrl+A` then `H/J/K/L` | Resize pane (Shift = resize) |
| `Ctrl+A` then `z` | Zoom pane (fullscreen toggle) |
| `Ctrl+A` then `x` | Kill current pane |

**Copy mode (scroll and select text):**

| Shortcut | Action |
|---|---|
| `Ctrl+A` then `[` | Enter copy mode (scroll with mouse or j/k) |
| `v` (in copy mode) | Start text selection |
| `y` (in copy mode) | Copy selection to clipboard |
| `q` (in copy mode) | Exit copy mode |

**Other:**

| Shortcut | Action |
|---|---|
| `Ctrl+A` then `r` | Reload tmux config |
| `Ctrl+A` then `t` | Show clock |
| `Ctrl+A` then `?` | List all keybindings |

### Common tmux Commands

```bash
# Start a new named session
tmux new -s myproject

# Detach: Ctrl+A, then d

# List sessions
tmux ls

# Reattach to a session
tmux attach -t myproject

# Kill a session
tmux kill-session -t myproject

# Create session or attach if it exists
tmux new -As myproject
```

### Recommended tmux Workflow

1. Start a session: `tmux new -s ml-project`
2. Split into panes: `Ctrl+A |` for side-by-side, `Ctrl+A -` for top/bottom
3. Open Neovim in one pane, keep a shell in the other
4. Use `Ctrl+A z` to zoom a pane for full-screen work, press again to unzoom
5. Create a new window (`Ctrl+A c`) for separate tasks
6. Detach (`Ctrl+A d`) when you're done — everything stays running
7. Reattach later: `tmux attach -t ml-project`

---

## 8. Neovim + LazyVim

**What:** Neovim is a modern, extensible text editor. LazyVim is a
pre-configured setup that turns it into a full IDE.
**Config:** `~/.config/nvim/`

### Why Neovim?
- Runs in the terminal (works over SSH, in tmux, everywhere)
- Extremely fast, even on huge files
- Fully customizable with Lua
- LSP support (same intelligence as VS Code — autocomplete, go-to-definition, etc.)
- Massive plugin ecosystem

### Vim Basics — Survival Guide

Vim has **modes**. This is the #1 thing that confuses beginners:

| Mode | How to enter | What it does |
|---|---|---|
| **Normal** | Press `Esc` | Navigate, delete, copy, paste — this is "home base" |
| **Insert** | Press `i` | Type text (like a normal editor) |
| **Visual** | Press `v` | Select text |
| **Command** | Press `:` | Run commands (save, quit, search-replace) |

**The golden rule:** When in doubt, press `Esc` to go back to Normal mode.

### Essential Vim Motions

**Navigation (Normal mode):**

| Key | Movement |
|---|---|
| `h` `j` `k` `l` | Left, Down, Up, Right (instead of arrow keys) |
| `w` | Jump forward one word |
| `b` | Jump backward one word |
| `0` | Jump to beginning of line |
| `$` | Jump to end of line |
| `gg` | Jump to top of file |
| `G` | Jump to bottom of file |
| `Ctrl+d` | Scroll down half page |
| `Ctrl+u` | Scroll up half page |
| `{` / `}` | Jump to previous / next paragraph |
| `%` | Jump to matching bracket |

**Editing (Normal mode):**

| Key | Action |
|---|---|
| `i` | Insert before cursor |
| `a` | Insert after cursor |
| `A` | Insert at end of line |
| `o` | Open new line below and insert |
| `O` | Open new line above and insert |
| `x` | Delete character under cursor |
| `dd` | Delete entire line |
| `yy` | Copy (yank) entire line |
| `p` | Paste after cursor |
| `P` | Paste before cursor |
| `u` | Undo |
| `Ctrl+r` | Redo |
| `.` | Repeat last action (incredibly powerful) |

**The "verb + motion" grammar:**

Vim commands compose like a language. A **verb** (action) + a **motion**
(target) = a command:

| Verb | Meaning |
|---|---|
| `d` | Delete |
| `c` | Change (delete + enter insert mode) |
| `y` | Yank (copy) |

| Motion | Meaning |
|---|---|
| `w` | From cursor to next word |
| `$` | From cursor to end of line |
| `iw` | "Inner word" (the word under cursor) |
| `i"` | "Inner quotes" (text between quotes) |
| `ip` | "Inner paragraph" |
| `i{` | "Inner braces" (content between {}) |

**Combine them:**
- `dw` = delete to next word
- `d$` = delete to end of line
- `ciw` = change inner word (delete word, start typing)
- `ci"` = change inner quotes (delete quoted text, start typing)
- `yip` = yank inner paragraph
- `di{` = delete inner braces

**Searching:**

| Key | Action |
|---|---|
| `/pattern` | Search forward |
| `?pattern` | Search backward |
| `n` | Next match |
| `N` | Previous match |
| `*` | Search for word under cursor |

**Saving and quitting:**

| Command | Action |
|---|---|
| `:w` | Save (write) |
| `:q` | Quit |
| `:wq` | Save and quit |
| `:q!` | Quit without saving |
| `ZZ` | Save and quit (shortcut) |

### LazyVim-Specific Keymaps

LazyVim uses `Space` as the **leader key**. Press `Space` and wait — a
popup (which-key) shows you all available commands.

**Most Important:**

| Shortcut | Action |
|---|---|
| `Space` | Open which-key menu (shows all commands) |
| `Space f f` | Find files (fuzzy search) |
| `Space f g` | Live grep (search file contents) |
| `Space e` | Toggle file explorer (neo-tree) |
| `Space b d` | Close current buffer (file) |
| `Space q q` | Quit all |

**Code Intelligence (LSP):**

| Shortcut | Action |
|---|---|
| `gd` | Go to definition |
| `gr` | Go to references |
| `K` | Show hover documentation |
| `Space c a` | Code actions (quick fixes, refactors) |
| `Space c r` | Rename symbol (across all files) |
| `]d` / `[d` | Next / previous diagnostic (error/warning) |

**Git (inside Neovim):**

| Shortcut | Action |
|---|---|
| `Space g g` | Open lazygit |
| `]h` / `[h` | Next / previous git hunk (change) |
| `Space g b` | Git blame (who changed this line) |

**Window Management:**

| Shortcut | Action |
|---|---|
| `Space -` | Split window horizontally |
| `Space \|` | Split window vertically |
| `Ctrl+h/j/k/l` | Navigate between windows |

### First Launch
The first time you open `nvim`, LazyVim will automatically:
1. Install the Lazy.nvim plugin manager
2. Download and install all configured plugins
3. Install treesitter parsers (for syntax highlighting)
4. Install LSP servers (pyright for Python, ruff for linting)
5. Install DAP adapters (debugpy for Python debugging)

This takes 1-2 minutes with a good internet connection. Subsequent launches
are instant.

### Python-Specific Features
Your config includes:
- **Pyright** — type checking and autocomplete for Python
- **Ruff** — ultra-fast linting and formatting (replaces flake8, black, isort)
- **debugpy** — interactive Python debugging with breakpoints
- **iron.nvim** — REPL integration (send code to a Python interpreter, Jupyter-like)

To use the REPL:
1. Open a Python file
2. `Space r s` — Start REPL (opens a Python interpreter in a split)
3. Select code in Visual mode, then `Space r s` — Send selection to REPL
4. `Space r l` — Send current line to REPL

---

## 9. Git Tools

### lazygit

**What:** A visual, interactive terminal UI for Git.
**Launch:** Type `lg` (aliased) or `lazygit`

Instead of memorizing Git commands, you navigate panels with your keyboard.
Think of it as GitHub Desktop, but in your terminal.

**Layout:**
```
┌──────────┬──────────────────────────────┐
│ Status   │                              │
│ Files    │    Diff / Preview             │
│ Branches │                              │
│ Commits  │                              │
│ Stash    │                              │
└──────────┴──────────────────────────────┘
```

**Essential Shortcuts:**

| Key | Action |
|---|---|
| `Tab` / numbers | Switch between panels |
| `Space` | Stage/unstage a file |
| `a` | Stage/unstage all files |
| `c` | Commit |
| `P` (Shift+P) | Push |
| `p` | Pull |
| `v` | Select lines to stage (partial staging) |
| `s` | Squash commit into previous |
| `i` | Start interactive rebase |
| `z` / `Ctrl+Z` | Undo / Redo (yes, undo git operations!) |
| `/` | Filter current panel |
| `q` | Quit |
| `?` | Help (show all keybindings) |

**Killer feature:** Undo (`z`). Made a mistake? lazygit can undo most git
operations, including commits, rebases, and merges.

### delta

**What:** A syntax-highlighting pager for Git diffs.
**Config:** Already set up in your `~/.gitconfig`

Delta automatically enhances the output of:
- `git diff` — see changes with syntax highlighting
- `git log -p` — see commit diffs beautifully
- `git show` — see a specific commit
- `git blame` — see who changed each line

You don't need to do anything special — it works automatically with all
git commands.

**Navigation while viewing diffs:**
- `n` / `N` — jump between diff sections
- `q` — quit
- `/pattern` — search
- `Space` — page down
- `b` — page up

### glab

**What:** GitLab CLI — interact with GitLab from your terminal.

```bash
glab mr list          # List merge requests
glab mr create        # Create a merge request
glab mr view 123      # View MR #123
glab issue list       # List issues
glab ci status        # Check CI/CD pipeline status
```

---

## 10. File Navigation

### zoxide — Smarter cd

**What:** Replaces the `cd` command with a learning directory jumper.
**Commands:** `z` and `zi`

zoxide remembers every directory you visit. Instead of typing full paths,
type a few characters:

```bash
# Instead of:
cd ~/Documents/Projects/my-ml-project/src/models

# Just type:
z models

# Or even shorter:
z mod

# Multiple keywords narrow it down:
z ml src

# Interactive mode (shows a list with fzf):
zi models
```

**How it learns:** Every time you `cd` (or `z`) into a directory, zoxide
records it. Frequently visited directories rank higher. Over time, `z`
becomes incredibly accurate.

```bash
# Regular cd still works too
z ~/some/explicit/path

# Go back to previous directory
z -

# Go up one level
z ..
```

### fzf — Fuzzy Finder

**What:** A general-purpose fuzzy finder. Type a few characters, it narrows
down a list of items in real-time.

**Shell Integration (already configured):**

| Shortcut | Action |
|---|---|
| `Ctrl+R` | Fuzzy search command history |
| `Ctrl+T` | Fuzzy find a file, paste its path |
| `Alt+C` | Fuzzy find a directory, cd into it |
| `**` then `Tab` | Fuzzy completion for any command |

**Examples of `**` completion:**

```bash
vim **<Tab>           # Fuzzy-find a file to edit
cd **<Tab>            # Fuzzy-find a directory
kill **<Tab>          # Fuzzy-find a process to kill
ssh **<Tab>           # Fuzzy-find a host
export **<Tab>        # Fuzzy-find an environment variable
```

**Standalone usage:**

```bash
# Pipe anything into fzf
cat names.txt | fzf

# Find and open a file
vim $(fzf)

# Preview files while browsing
fzf --preview 'bat --color=always {}'

# Multi-select with Tab
fzf -m
```

**Search syntax inside fzf:**

| Token | Meaning |
|---|---|
| `abc` | Fuzzy match |
| `'abc` | Exact match (prefix with `'`) |
| `^abc` | Must start with abc |
| `abc$` | Must end with abc |
| `!abc` | Must NOT contain abc |
| `a \| b` | Match a OR b |

### yazi — Terminal File Manager

**What:** A blazing-fast file manager in your terminal.
**Launch:** Type `y` (aliased — cd's to the directory you quit from)

Think of it as Windows Explorer, but keyboard-driven and much faster.

**Navigation:**

| Key | Action |
|---|---|
| `h` | Go to parent directory |
| `l` or `Enter` | Open file/enter directory |
| `j` / `k` | Move down / up |
| `g g` | Jump to top |
| `G` | Jump to bottom |
| `/` | Search |
| `z` | Jump with zoxide (type partial path) |

**File Operations:**

| Key | Action |
|---|---|
| `Space` | Toggle selection |
| `y` | Yank (copy) selected files |
| `d` | Delete selected files |
| `p` | Paste yanked files |
| `r` | Rename file |
| `a` | Create new file |
| `A` | Create new directory |

**Features:**
- Image preview in WezTerm
- Syntax-highlighted code preview
- Multi-tab (`t` to open new tab)
- Bulk rename selected files

**Why use `y` instead of `yazi`?** The `y` alias (defined in your `.zshrc`)
wraps yazi so that when you quit, your shell `cd`s to whatever directory
you were last browsing. Without the wrapper, quitting yazi returns you to
where you started.

---

## 11. Better Unix Commands

Your `.zshrc` aliases these as replacements for the old commands.

### bat — Better cat

**Replaces:** `cat`
**Alias:** `cat` → `bat --paging=never`

```bash
cat file.py             # Syntax-highlighted output (bat)
catp file.py            # Same but with paging (scrollable)
bat -n file.py          # Line numbers only (no header/grid)
bat -A file.py          # Show invisible characters (tabs, spaces)
bat --diff file.py      # Only show changed lines
bat -l json file.txt    # Force a specific syntax language
```

bat automatically:
- Detects the file language and applies syntax highlighting
- Shows line numbers
- Shows Git change markers in the gutter
- Falls back to plain output when piped to another command

### eza — Better ls

**Replaces:** `ls`
**Aliases:** `ls` → `eza --icons`, `ll` → `eza -la --icons --git`, etc.

```bash
ls                      # Colorized listing with icons (eza)
ll                      # Long listing with permissions, git status
la                      # Include hidden files
lt                      # Tree view (2 levels deep)

# Additional useful flags:
eza -l --sort=size      # Sort by file size
eza -l --sort=modified  # Sort by modification time
eza --tree -L 3         # Tree view, 3 levels deep
eza -l --git            # Show git status per file
eza --group-directories-first  # Directories first
```

### fd — Better find

**Replaces:** `find`

```bash
fd pattern              # Find files matching regex (recursive)
fd -e py                # Find all .py files
fd -e py model          # Find .py files matching "model"
fd -t d                 # Find only directories
fd -t f                 # Find only files
fd -H                   # Include hidden files
fd -d 2                 # Limit search depth to 2 levels
fd -S +1m               # Files larger than 1MB
fd --changed-within 1d  # Modified in the last day
fd -e py -x wc -l       # Count lines in every .py file (parallel!)
```

**Smart defaults:** fd respects `.gitignore`, skips hidden files, and uses
smart-case matching (case-insensitive unless your pattern has uppercase).
This means the output is clean and relevant by default.

### ripgrep (rg) — Better grep

**Replaces:** `grep`

```bash
rg pattern              # Search file contents recursively
rg -i pattern           # Case-insensitive
rg -w word              # Whole word match
rg pattern -t python    # Only search Python files
rg pattern -g '*.toml'  # Only search TOML files
rg -l pattern           # Just list files with matches
rg -c pattern           # Count matches per file
rg pattern -C 3         # Show 3 lines of context
rg -F 'literal string'  # Fixed string (no regex interpretation)
```

**Filtering levels:**
```bash
rg pattern              # Default: respects .gitignore, skips hidden files
rg -u pattern           # Also search gitignored files
rg -uu pattern          # Also search hidden files
rg -uuu pattern         # Also search binary files (everything)
```

**Common workflows:**
```bash
# Find all TODO comments in Python files
rg TODO -t python

# Find function definitions
rg 'def train_model'

# Search and replace (preview only — doesn't modify files)
rg 'old_name' -r 'new_name'

# Count occurrences across a project
rg -c 'import torch' | sort -t: -k2 -n
```

---

## 12. Python Toolchain

### uv — All-in-One Python Manager

**What:** Replaces pip, pip-tools, pipx, poetry, pyenv, and virtualenv.
Written in Rust, 10-100x faster than pip.

**Python version management:**

```bash
# List installed Python versions
uv python list --only-installed

# Install a new Python version
uv python install 3.12

# Pin a version for a project directory
uv python pin 3.11
```

**Project workflow (recommended):**

```bash
# Create a new project
uv init my-ml-project
cd my-ml-project

# Add dependencies
uv add torch torchvision
uv add numpy pandas matplotlib
uv add --dev pytest mypy ruff

# Run your code (automatically uses the project's virtualenv)
uv run python train.py
uv run pytest

# Lock dependencies (for reproducibility)
uv lock

# Sync environment to match lockfile
uv sync
```

**Quick scripts (no project needed):**

```bash
# Run a one-off script with dependencies
uv run --with requests python fetch_data.py

# Install a CLI tool globally
uv tool install ruff
uv tool install marimo

# Run a tool without installing (like npx)
uvx ruff check .
uvx black .
```

**As a pip replacement:**

```bash
# These work the same as pip, but 10-100x faster
uv pip install torch
uv pip install -r requirements.txt
uv pip compile requirements.in -o requirements.txt
```

**Your aliases:**
```bash
pip     → uv pip          # Faster pip
venv    → uv venv         # Create virtualenv
uvr     → uv run          # Run in project venv
```

### marimo — Reactive Python Notebooks

**What:** A modern alternative to Jupyter notebooks. Cells auto-update
when dependencies change (like a spreadsheet).
**Launch:** `marimo edit` (opens in your browser)

```bash
# Create/edit a notebook
marimo edit

# Open a specific notebook
marimo edit analysis.py

# Run a notebook as a web app
marimo run analysis.py

# Interactive tutorial
marimo tutorial intro
```

**Why marimo over Jupyter?**
- **No hidden state** — in Jupyter, you can run cells out of order and get
  stale variables. Marimo prevents this by design.
- **Reactive** — change one cell, dependent cells auto-update
- **Saved as `.py` files** — works with Git (no more giant JSON notebooks)
- **Built-in UI elements** — sliders, dropdowns, tables without callbacks

---

## 13. Containers (Podman)

**What:** A Docker-compatible container runtime that doesn't need a
background daemon and can run without root privileges.

**If you know Docker, you know Podman.** The commands are identical:

```bash
pd images              # List images       (alias for podman)
pd ps                  # List containers   (alias for podman)
pd pull python:3.12    # Pull an image
pd run -it python:3.12 # Run a container interactively
pd build -t myapp .    # Build from Dockerfile
pd stop <container>    # Stop a container
pd rm <container>      # Remove a container
```

**Your aliases:**
```bash
pd    → podman
pdr   → podman run
pdi   → podman images
pdc   → podman ps
```

**Why Podman over Docker?**
- No daemon (background service) needed
- Rootless by default (more secure)
- Same OCI images (pulls from Docker Hub, etc.)
- Drop-in replacement: `alias docker=podman` works

---

## 14. Dotfile Management (GNU Stow)

**What:** Manages symlinks so your config files can live in a Git repo
while appearing in the right places for each program.

### How Your Setup Works

Your dotfiles live in:
```
~/Documents/Projects/terminal_10x_engineer/
├── zsh/.zshrc                          # Real file
├── git/.gitconfig                      # Real file
├── nvim/.config/nvim/init.lua          # Real file
├── tmux/.config/tmux/tmux.conf         # Real file
└── ...
```

Stow creates symlinks so programs find them:
```
~/.zshrc → .../terminal_10x_engineer/zsh/.zshrc
~/.gitconfig → .../terminal_10x_engineer/git/.gitconfig
~/.config/nvim/init.lua → .../terminal_10x_engineer/nvim/.config/nvim/init.lua
```

### Stow Commands

```bash
# Go to your dotfiles repo
cd /mnt/c/Users/guyle/Documents/Projects/terminal_10x_engineer

# Stow a package (create symlinks)
stow zsh

# Un-stow a package (remove symlinks)
stow -D zsh

# Re-stow (remove then re-create — use after changing directory structure)
stow -R zsh

# Dry run (preview what would happen)
stow -n -v zsh

# Stow all packages at once
stow zsh starship nvim tmux yazi git podman
```

### Why This Matters
- All your config is version-controlled (you can `git commit` changes)
- Setting up a new machine = clone repo + run stow
- You can experiment: `stow -D nvim` removes your Neovim config, try something
  else, then `stow nvim` to bring it back

---

## 15. Tokyo Night

**What:** A clean, dark color scheme applied consistently across all your tools.
**Variant:** Night (the darkest variant)

Tokyo Night is applied to:
- WezTerm (terminal colors)
- Neovim (editor theme via tokyonight.nvim)
- tmux (status bar)
- fzf (fuzzy finder)
- bat (syntax highlighting — uses "Visual Studio Dark+" by default, see .zshrc for Tokyo Night install)
- delta (git diffs — uses "base16", closest built-in match)
- starship (prompt inherits terminal colors)

This gives your entire environment a unified, cohesive look. The palette
uses cool blues, soft purples, and muted cyans that are easy on the eyes
during long coding sessions.

**Colorblind alternatives** are available in `nvim/.config/nvim/lua/plugins/colorscheme.lua`
and `wezterm/.wezterm.lua` — uncomment the nightfox family themes which have
built-in daltonization (color vision deficiency) support.

---

## 16. Aliases Cheat Sheet

These are defined in your `~/.zshrc`. Type the alias instead of the full
command:

### Navigation
| Alias | Expands To | What It Does |
|---|---|---|
| `..` | `cd ..` | Go up one directory |
| `...` | `cd ../..` | Go up two directories |
| `ls` | `eza --icons` | Colorized file listing |
| `ll` | `eza -la --icons --git` | Detailed listing with git status |
| `la` | `eza -a --icons` | List all (including hidden) |
| `lt` | `eza --tree --level=2 --icons` | Tree view |
| `y` | yazi wrapper | File manager (cd on exit) |
| `z` | zoxide | Smart directory jump |

### Files
| Alias | Expands To | What It Does |
|---|---|---|
| `cat` | `bat --paging=never` | View file with syntax highlighting |
| `catp` | `bat` | View file with paging |

### Git
| Alias | Expands To | What It Does |
|---|---|---|
| `g` | `git` | Git shortcut |
| `gs` | `git status` | Check repo status |
| `ga` | `git add` | Stage files |
| `gc` | `git commit` | Commit changes |
| `gp` | `git push` | Push to remote |
| `gl` | `git log --oneline --graph` | Visual commit log |
| `gd` | `git diff` | Show changes |
| `lg` | `lazygit` | Visual git TUI |

### Python
| Alias | Expands To | What It Does |
|---|---|---|
| `py` | `python3` | Python shortcut |
| `pip` | `uv pip` | Fast pip replacement |
| `venv` | `uv venv` | Create virtualenv |
| `uvr` | `uv run` | Run in project venv |

### Editor
| Alias | Expands To | What It Does |
|---|---|---|
| `v` | `nvim` | Open Neovim |
| `vi` | `nvim` | Open Neovim |
| `vim` | `nvim` | Open Neovim |

### Containers
| Alias | Expands To | What It Does |
|---|---|---|
| `pd` | `podman` | Podman shortcut |
| `pdr` | `podman run` | Run container |
| `pdi` | `podman images` | List images |
| `pdc` | `podman ps` | List containers |

---

## 17. Daily Workflow Examples

### Starting Your Day

```bash
# 1. Open WezTerm (it connects to Fedora WSL automatically)
# 2. Start or reattach a tmux session
tmux new -As work

# 3. Navigate to your project
z my-project        # zoxide remembers it

# 4. Split tmux for editor + shell
# Ctrl+A then |   (side by side)

# 5. Open your editor
v                   # opens Neovim
```

### Working on a Python ML Project

```bash
# Create a new project
uv init my-ml-project
cd my-ml-project

# Add dependencies
uv add torch torchvision numpy pandas matplotlib

# Add dev dependencies
uv add --dev pytest ruff mypy

# Open in Neovim
v .

# In Neovim:
#   Space f f     → find files
#   Space f g     → search code
#   Space e       → file explorer
#   gd            → go to definition
#   K             → hover docs
#   Space c a     → code actions (fix imports, etc.)

# Run your code (from the shell pane)
uvr python train.py

# Run tests
uvr pytest

# Use the REPL in Neovim for exploration
#   Space r s     → start Python REPL
#   Select code, Space r s → send to REPL
```

### Git Workflow

```bash
# Option A: Use lazygit (visual)
lg
# Stage files with Space, commit with c, push with P

# Option B: Use git aliases (quick)
gs                  # status
ga .                # stage all
gc -m "Add model"   # commit
gp                  # push

# View commit history
gl                  # oneline graph
```

### Exploring a New Codebase

```bash
# Find all Python files
fd -e py

# Search for a function definition
rg 'def train_model'

# Find large files
fd -S +10m

# Browse the project structure
lt                  # tree view
y                   # yazi file manager

# In Neovim:
#   Space f g     → live grep across all files
#   Space f f     → fuzzy find files by name
```

### Running Containers

```bash
# Pull and run a Python environment
pd run -it python:3.12 bash

# Build your project's container
pd build -t my-ml-app .

# Run your app in a container
pd run -p 8080:8080 my-ml-app
```

---

## 18. Troubleshooting

### "command not found"
Your tools are in `~/.local/bin`. Make sure it's in your PATH:
```bash
echo $PATH | tr ':' '\n' | head -5
```
If `~/.local/bin` is not listed, check your `~/.zprofile`.

### WezTerm won't open
1. Check the domain name matches: open PowerShell, run `wsl -l`, and ensure
   the name in `.wezterm.lua` matches exactly (e.g., `WSL:FedoraLinux-43`)
2. Try changing `WebGpu` to `OpenGL` in `.wezterm.lua`
3. Check `C:\Users\guyle\.wezterm.lua` exists (not just in the dotfiles repo)

### Neovim plugins not working
On first launch, wait for all plugins to install. If something fails:
```bash
# Inside Neovim:
:Lazy           # Open plugin manager
:Lazy sync      # Re-sync all plugins
:Mason          # Check LSP/DAP installations
:checkhealth    # Run health checks
```

### Fonts look wrong (squares/boxes instead of icons)
Install JetBrains Mono Nerd Font on Windows. The Nerd Font version includes
icons. Regular JetBrains Mono does not have the icons.

### tmux colors look wrong
Make sure your `TERM` is set correctly:
```bash
echo $TERM
# Should be: tmux-256color (inside tmux) or xterm-256color (outside)
```

### Shell starts slowly
Zinit turbo mode loads plugins after the prompt. If it's still slow:
```bash
# Time your shell startup
time zsh -i -c exit

# Anything under 200ms is good
```

### WSL is slow on /mnt/c/ files
The Windows filesystem (`/mnt/c/`) is slow from WSL. For performance-critical
work (Python projects, Git repos), copy files to the Linux filesystem:
```bash
cp -r /mnt/c/Users/guyle/Projects/my-project ~/Projects/
cd ~/Projects/my-project
```
This can be 10-50x faster for file-heavy operations.
