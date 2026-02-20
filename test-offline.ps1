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

# ── Cleanup ──────────────────────────────────────────────────────────────────
function Remove-TestDistro {
    $existing = wsl --list --quiet 2>$null | Where-Object { $_ -match $TestDistro }
    if ($existing) {
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
rm -f  /home/$TestUser/.zshrc /home/$TestUser/.zprofile /home/$TestUser/.gitconfig /home/$TestUser/.gitignore_global
rm -rf /home/$TestUser/.cache/zsh
echo 'Reset complete'
"@
wsl -d $TestDistro -u root -- sh -c $resetScript
Write-Ok "Test distro reset to clean state"

# ── Step 4: Simulate airgap (block network inside WSL) ──────────────────────
Write-Step "Blocking network inside test distro (simulating airgap)..."

# Drop all outbound traffic except loopback
$firewallScript = @"
set -e
iptables -F OUTPUT 2>/dev/null || true
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -j DROP

# Verify: this curl SHOULD fail
if curl -s --max-time 3 https://github.com >/dev/null 2>&1; then
    echo 'ERROR: Network still reachable!'
    exit 1
else
    echo 'Network blocked — airgap simulation active'
fi
"@
wsl -d $TestDistro -u root -- sh -c $firewallScript
Write-Ok "Network blocked via iptables"

# ── Step 5: Copy bundle + repo into the test distro ─────────────────────────
Write-Step "Copying repo and bundle into test distro..."

$wslRepoRoot = $RepoRoot -replace '\\','/' -replace 'C:','/mnt/c'
$wslBundle = $bundle.FullName -replace '\\','/' -replace 'C:','/mnt/c'

# Copy the repo (via /mnt/c which is always available) to a local ext4 path
$copyScript = @"
set -e
rm -rf /tmp/dotfiles-test
cp -a '$wslRepoRoot' /tmp/dotfiles-test
cp '$wslBundle' /tmp/dotfiles-test/airgap/
chown -R ${TestUser}:${TestUser} /tmp/dotfiles-test
echo 'Repo and bundle copied to /tmp/dotfiles-test'
"@
wsl -d $TestDistro -u root -- sh -c $copyScript
Write-Ok "Files staged in test distro"

# ── Step 6: Run deploy.sh ───────────────────────────────────────────────────
Write-Step "Running airgap deployment..."

$deployScript = @"
set -e
cd /tmp/dotfiles-test
bash airgap/deploy.sh --user $TestUser --force airgap/$($bundle.Name)
"@
wsl -d $TestDistro -u root -- sh -c $deployScript
Write-Ok "Deployment completed"

# ── Step 7: Verify tools ────────────────────────────────────────────────────
Write-Step "Verifying installed tools..."

$verifyScript = @'
#!/usr/bin/env bash
set -euo pipefail
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
check "starship"   "starship --version"
check "zoxide"     "zoxide --version"
check "fzf"        "fzf --version"
check "bat"        "bat --version"
check "eza"        "eza --version"
check "ripgrep"    "rg --version"
check "fd"         "fd --version"
check "yazi"       "yazi --version"
check "lazygit"    "lazygit --version"
check "delta"      "delta --version"
check "nvim"       "nvim --version"
check "uv"         "uv --version"
check "glab"       "glab --version"
check "jf"         "jf --version"
check "helm"       "helm version --short"
check "oc"         "oc version --client"

echo ""
echo "Config verification:"
check "zshrc"         "test -L ~/.zshrc"
check "starship.toml" "test -L ~/.config/starship.toml"
check "nvim config"   "test -L ~/.config/nvim/init.lua"
check "tmux.conf"     "test -L ~/.config/tmux/tmux.conf"
check "yazi.toml"     "test -L ~/.config/yazi/yazi.toml"
check "gitconfig"     "test -L ~/.gitconfig"
check "registries"    "test -L ~/.config/containers/registries.conf"
check "zinit"         "test -d ~/.local/share/zinit/zinit.git"

echo ""
echo "Results: $passed/$total passed, $failed failed"
exit $failed
'@
$verifyResult = wsl -d $TestDistro -u $TestUser -- sh -c $verifyScript
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
