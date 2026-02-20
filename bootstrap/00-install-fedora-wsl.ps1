# 00-install-fedora-wsl.ps1
# Install Fedora 43 on WSL2. That's it.
#
# Fedora is now natively available in `wsl --list --online` (since 2025).
# No rootfs download, no import, no 7-Zip — just one command.
#
# Usage:  powershell -File bootstrap\00-install-fedora-wsl.ps1
# Or just run the one-liner below manually.
#
# NOTE: If you already have AlmaLinux, skip this script entirely.
#       The remaining scripts are RPM/dnf-compatible and work on both.

# Check available distros:  wsl --list --online
# Install:
wsl --install -d FedoraLinux-43

Write-Host ""
Write-Host "Done. Fedora 43 installed on WSL2." -ForegroundColor Green
Write-Host ""
Write-Host "Next: open Fedora from WezTerm, then run:" -ForegroundColor Cyan
Write-Host "  sudo bash bootstrap/01-create-user.sh" -ForegroundColor White
Write-Host ""
Write-Host "If WSL is not enabled yet, run first:" -ForegroundColor Yellow
Write-Host "  wsl --install --no-distribution" -ForegroundColor White
Write-Host "  # then reboot and re-run this script" -ForegroundColor DarkGray
