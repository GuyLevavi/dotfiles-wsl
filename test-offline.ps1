# =============================================================================
# test-offline.ps1 — Test airgap deployment using a cloned WSL distro
# =============================================================================
# Creates a disposable copy of your Fedora WSL distro, disconnects it from
# the network, deploys the bundle inside it, and verifies all tools work.
#
# Usage:
#   .\test-offline.ps1                 # full test (bundle + deploy + verify)
#   .\test-offline.ps1 -SkipBundle     # reuse existing bundle
#   .\test-offline.ps1 -Cleanup        # just remove the test distro
#
# Requirements:
#   - FedoraLinux-43 WSL distro installed (the source)
#   - An existing bundle tarball OR internet access to create one
# =============================================================================

param(
    [switch]$SkipBundle,
    [switch]$Cleanup,
    [string]$TestDistro = "FedoraLinux-43-test",
    [string]$TestUser = "gl"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestDir = Join-Path $env:LOCALAPPDATA "WSL\$TestDistro"

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  + $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  X $msg" -ForegroundColor Red }

# Write a script into the test WSL distro without BOM and with Unix line endings
function Write-WslScript {
    param([string]$Path, [string]$Content)
    # Write to a temp file on Windows with LF line endings (no CRLF, no BOM)
    $tmpFile = [System.IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $unixContent = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($tmpFile, $unixContent, $utf8NoBom)
    $wslTmp = $tmpFile -replace '\\','/' -replace 'C:','/mnt/c'
    wsl -d $TestDistro -u root -- sh -c "cp '$wslTmp' '$Path' && chmod +x '$Path'"
    Remove-Item $tmpFile -Force
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
function Remove-TestDistro {
    # wsl --list outputs UTF-16 with null bytes — clean it up for matching
    $raw = wsl --list --quiet 2>$null | Out-String
    $clean = $raw -replace "`0", ""
    if ($clean -match $TestDistro) {
        Write-Step "Removing test distro: $TestDistro"
        wsl --terminate $TestDistro 2>$null
        wsl --unregister $TestDistro
        Write-Ok "Unregistered $TestDistro"
    }
    if (Test-Path $TestDir) {
        Remove-Item -Recurse -Force $TestDir
        Write-Ok "Removed $TestDir"
    }
}

if ($Cleanup) {
    Remove-TestDistro
    Write-Host "`nCleanup complete." -ForegroundColor Green
    exit 0
}

# ── Step 1: Create bundle (unless -SkipBundle) ──────────────────────────────
$bundle = Get-ChildItem -Path "$RepoRoot\airgap" -Filter "devenv-bundle-*.tar.gz" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $SkipBundle) {
    Write-Step "Creating airgap bundle..."
    wsl -d FedoraLinux-43 -u $TestUser -- bash -c "cd '$($RepoRoot -replace '\\','/' -replace 'C:','/mnt/c')' && bash airgap/bundle.sh"
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Bundle creation failed (exit code: $LASTEXITCODE)"
        exit 1
    }
    $bundle = Get-ChildItem -Path "$RepoRoot\airgap" -Filter "devenv-bundle-*.tar.gz" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not $bundle) {
    Write-Fail "No bundle found in airgap/. Run without -SkipBundle first."
    exit 1
}
Write-Ok "Using bundle: $($bundle.Name)"

# ── Step 2: Clone the WSL distro ────────────────────────────────────────────
Remove-TestDistro

Write-Step "Exporting FedoraLinux-43..."
$exportPath = Join-Path $env:TEMP "fedora-test-export.tar"
wsl --export FedoraLinux-43 $exportPath
Write-Ok "Exported to $exportPath"

Write-Step "Importing as $TestDistro..."
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
wsl --import $TestDistro $TestDir $exportPath
Remove-Item $exportPath -Force
Write-Ok "Imported $TestDistro"

# ── Step 3: Reset the test distro to a clean state ──────────────────────────
Write-Step "Resetting test distro to clean state..."

# Remove all user-space tools and configs to simulate a fresh machine
$resetScript = @"
set -e
# Remove user-installed tools
rm -rf /home/$TestUser/.local/bin/*
rm -rf /home/$TestUser/.local/share/zinit
rm -rf /home/$TestUser/.local/share/nvim
rm -rf /home/$TestUser/.local/state/nvim
rm -rf /home/$TestUser/.config/nvim
rm -rf /home/$TestUser/.config/starship.toml
rm -rf /home/$TestUser/.config/tmux
rm -rf /home/$TestUser/.config/yazi
rm -rf /home/$TestUser/.config/containers
rm -rf /home/$TestUser/.config/opencode
rm -rf /home/$TestUser/.config/codex
rm -rf /home/$TestUser/.codex
rm -f  /home/$TestUser/.zshrc /home/$TestUser/.zprofile /home/$TestUser/.gitconfig /home/$TestUser/.gitignore_global
rm -rf /home/$TestUser/.cache/zsh
# Remove any previous dotfiles repo copy (stow target)
rm -rf /home/$TestUser/dotfiles
# Remove system packages that deploy.sh should install from cached RPMs.
# This ensures the airgap RPM pipeline is actually tested.
# Keep bash, coreutils, dnf, rpm — they're needed to run the deploy script itself.
dnf remove -y stow podman buildah skopeo fuse-overlayfs tmux ShellCheck 2>/dev/null || true
echo 'Reset complete'
"@
Write-WslScript -Path "/tmp/reset-distro.sh" -Content $resetScript
wsl -d $TestDistro -u root -- bash /tmp/reset-distro.sh
Write-Ok "Test distro reset to clean state"

# ── Step 4: Simulate airgap (block network inside WSL) ──────────────────────
Write-Step "Blocking network inside test distro (simulating airgap)..."

# Drop all outbound traffic except loopback using nftables (Fedora 43 default).
# Persist via nftables.service so rules survive WSL restarts.
$firewallScript = @"
set -e
nft flush ruleset
nft add table inet filter
nft add chain inet filter output '{ type filter hook output priority 0; policy drop; }'
nft add rule inet filter output oifname lo accept

# Persist: save rules and enable nftables service to reload on boot
nft list ruleset > /etc/sysconfig/nftables.conf
systemctl enable nftables.service 2>/dev/null || true

# Verify: this curl SHOULD fail
if curl -s --max-time 3 https://github.com >/dev/null 2>&1; then
    echo 'ERROR: Network still reachable!'
    exit 1
else
    echo 'Network blocked — airgap simulation active (persistent)'
fi
"@
Write-WslScript -Path "/tmp/block-network.sh" -Content $firewallScript
wsl -d $TestDistro -u root -- bash /tmp/block-network.sh
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Network blocking failed (exit code: $LASTEXITCODE)"
    exit 1
}
Write-Ok "Network blocked via nftables"

# ── Step 5: Copy bundle + repo into the test distro ─────────────────────────
Write-Step "Copying repo and bundle into test distro..."

$wslRepoRoot = $RepoRoot -replace '\\','/' -replace 'C:','/mnt/c'
$wslBundle = $bundle.FullName -replace '\\','/' -replace 'C:','/mnt/c'

# Copy the repo (via /mnt/c which is always available) to a persistent ext4 path.
# MUST NOT use /tmp — systemd cleans it on restart, breaking stow symlinks.
$dotfilesDir = "/home/$TestUser/dotfiles"
$copyScript = @"
set -e
rm -rf $dotfilesDir
cp -a '$wslRepoRoot' $dotfilesDir
cp '$wslBundle' $dotfilesDir/airgap/
chown -R ${TestUser}:${TestUser} $dotfilesDir
echo 'Repo and bundle copied to $dotfilesDir'
"@
Write-WslScript -Path "/tmp/copy-repo.sh" -Content $copyScript
wsl -d $TestDistro -u root -- bash /tmp/copy-repo.sh
if ($LASTEXITCODE -ne 0) {
    Write-Fail "File copy failed (exit code: $LASTEXITCODE)"
    exit 1
}
Write-Ok "Files staged in test distro"

# ── Step 6: Run deploy.sh ───────────────────────────────────────────────────
Write-Step "Running airgap deployment..."

$deployScript = @"
set -e
cd $dotfilesDir
bash airgap/deploy.sh --user $TestUser --force airgap/$($bundle.Name)
"@
Write-WslScript -Path "/tmp/run-deploy.sh" -Content $deployScript
wsl -d $TestDistro -u root -- bash /tmp/run-deploy.sh
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Deployment failed (exit code: $LASTEXITCODE)"
    exit 1
}
Write-Ok "Deployment completed"

# ── Step 7: Verify tools ────────────────────────────────────────────────────
Write-Step "Verifying installed tools..."

# Write verification script to a file inside the test distro, then run it.
# Passing multiline scripts via sh -c from PowerShell mangles the content.
$verifyScript = @'
#!/usr/bin/env bash
set -euo pipefail

# Ensure HOME is set correctly (imported WSL distros may not set it)
HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
export HOME

# Tools are installed to ~/.local/bin
BIN="$HOME/.local/bin"
export PATH="$BIN:$PATH"

passed=0 failed=0 total=0

check() {
    local name="$1" cmd="$2"
    total=$((total + 1))
    if eval "$cmd" >/dev/null 2>&1; then
        echo "  + $name"
        passed=$((passed + 1))
    else
        echo "  X $name FAILED"
        failed=$((failed + 1))
    fi
}

echo "Tool verification:"
check "starship"   "$BIN/starship --version"
check "zoxide"     "$BIN/zoxide --version"
check "fzf"        "$BIN/fzf --version"
check "bat"        "$BIN/bat --version"
check "eza"        "$BIN/eza --version"
check "ripgrep"    "$BIN/rg --version"
check "fd"         "$BIN/fd --version"
check "yazi"       "test -x $BIN/yazi"
check "lazygit"    "$BIN/lazygit --version"
check "delta"      "$BIN/delta --version"
check "nvim"       "$BIN/nvim --version"
check "uv"         "$BIN/uv --version"
check "glab"       "$BIN/glab --version"
check "jf"         "$BIN/jf --version"
check "helm"       "$BIN/helm version --short"
check "oc"         "$BIN/oc version --client"

echo ""
echo "Config verification:"
# Stow may symlink parent dirs, so check file existence (-f) not symlink (-L).
# For top-level dotfiles (e.g. .zshrc), stow creates file-level symlinks.
check "zshrc"         "test -L ~/.zshrc"
check "starship.toml" "test -f ~/.config/starship.toml"
check "nvim config"   "test -f ~/.config/nvim/init.lua"
check "tmux.conf"     "test -f ~/.config/tmux/tmux.conf"
check "yazi.toml"     "test -f ~/.config/yazi/yazi.toml"
check "gitconfig"     "test -L ~/.gitconfig"
check "registries"    "test -f ~/.config/containers/registries.conf"
check "zinit"         "test -d ~/.local/share/zinit/zinit.git"

echo ""
echo "System package verification:"
check "stow"      "command -v stow"
check "zsh"       "command -v zsh"
check "tmux"      "command -v tmux"
check "git"       "command -v git"
check "podman"    "command -v podman"
check "buildah"   "command -v buildah"
check "skopeo"    "command -v skopeo"
check "nodejs"    "command -v node"
check "npm"       "command -v npm"
check "jq"        "command -v jq"
check "python3"   "command -v python3"

echo ""
echo "Plugin verification (zinit offline cache):"
check "fast-syntax-highlighting" "test -d ~/.local/share/zinit/plugins/zdharma-continuum---fast-syntax-highlighting"
check "zsh-autosuggestions"      "test -d ~/.local/share/zinit/plugins/zsh-users---zsh-autosuggestions"
check "zsh-completions"          "test -d ~/.local/share/zinit/plugins/zsh-users---zsh-completions"
check "fzf-tab"                  "test -d ~/.local/share/zinit/plugins/Aloxaf---fzf-tab"

echo ""
echo "Results: $passed/$total passed, $failed failed"
exit $failed
'@

Write-WslScript -Path "/tmp/verify-tools.sh" -Content $verifyScript
$verifyResult = wsl -d $TestDistro -u $TestUser -- bash /tmp/verify-tools.sh
$verifyResult | ForEach-Object { Write-Host $_ }

# ── Step 8: Summary ─────────────────────────────────────────────────────────
Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "The airgap bundle deploys correctly on a clean system."
} else {
    Write-Host "SOME TESTS FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    Write-Host "Review the output above for details."
}

Write-Host ""
Write-Host "The test distro '$TestDistro' is still running."
Write-Host "  Inspect:  wsl -d $TestDistro -u $TestUser"
Write-Host "  Cleanup:  .\test-offline.ps1 -Cleanup"
