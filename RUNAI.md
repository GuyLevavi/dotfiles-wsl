# Run:ai Deployment Guide

Deploy this dev environment onto Run:ai clusters by layering on your corporate base image.

---

## Quick Layering

```dockerfile
# Dockerfile.runai
# Stage 1 — dev env layer
FROM ghcr.io/guylevavi/dotfiles-wsl:latest-ubi9 AS devenv

# Stage 2 — your corporate GPU base image
FROM registry.your-company.com/ai/pytorch:2.3-cuda12-ubi9

# Recreate gl user
RUN useradd --create-home --shell /usr/bin/zsh --uid 1000 gl \
    && mkdir -p /etc/sudoers.d \
    && echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd \
    && chmod 0440 /etc/sudoers.d/wheel-nopasswd \
    && usermod --append --groups wheel gl

# Copy pre-installed home directory
COPY --from=devenv --chown=gl:gl /home/gl /home/gl

USER gl
WORKDIR /home/gl
ENV SHELL=/usr/bin/zsh PATH="/home/gl/.local/bin:$PATH"
CMD ["/usr/bin/zsh"]
```

```bash
# Build and push
docker build -f Dockerfile.runai \
  -t registry.your-company.com/your-team/dev-env:latest .
docker push registry.your-company.com/your-team/dev-env:latest
```

---

## Run:ai Workload

```bash
# Interactive session
runai submit dev-session \
  --image registry.your-company.com/your-team/dev-env:latest \
  --interactive --attach --gpu 1 -- zsh

# Or via YAML
runai apply -f runai-workspace.yaml
runai bash dev-session
```

**runai-workspace.yaml:**
```yaml
apiVersion: run.ai/v2alpha1
kind: TrainingWorkload
metadata:
  name: dev-session
spec:
  gpu:
    value: "1"
  image:
    value: registry.your-company.com/your-team/dev-env:latest
  command:
    value: zsh
  interactive:
    value: true
  runAsUser:
    value: true
  # Optional: persistent home
  # storage:
  #   pvc:
  #     - claimName: gl-home
  #       path: /home/gl
  #       existingPvc: true
```

---

## Important: User Mismatch Fix

Run:ai images often run as root or a different user. The dev env configs target `gl` (uid 1000).

**Option A: Map to gl user (recommended)**
```yaml
spec:
  runAsUser:
    value: true  # maps submitting user to uid 1000
```

**Option B: Deploy with --user flag**
```bash
# If base image uses 'jensen' user
bash airgap/deploy.sh --user jensen --force bundle.tar.gz
```

**Option C: Use root (not recommended)**
Configs will still work but ownership will be messy.

---

## Offline Bundle Deployment

On airgapped Run:ai cluster:

```bash
# 1. Copy bundle to shared storage
# 2. Submit job with bundle mount
runai submit dev-session \
  --image registry.your-company.com/ai/pytorch:2.3-cuda12-ubi9 \
  --pvc storage:/data \
  --interactive --attach --gpu 1 \
  -- /bin/bash -c "
    cd /home/user && \
    tar -xzf /data/devenv-bundle-*.tar.gz && \
    bash airgap/deploy.sh --user \$USER --force && \
    exec zsh
  "
```

---

## Verifying Deployment

Inside the container:
```bash
which nvim zsh uv       # All present?
nvim --version          # LazyVim loads?
python3 --version       # Python available?
pytest --version        # neotest-python requirement
```

---

## Troubleshooting

**nvim plugins missing:**
- The bundle includes `nvim-data.tar.gz` with all plugins
- If missing, regenerate: run `prep-nvim.sh` online, then `bundle.sh`

**Permission denied on /home/gl:**
- User in container doesn't match `gl:gl` ownership
- Use `--user` flag or adjust Dockerfile COPY chown

**Tools not in PATH:**
- Check `~/.local/bin/` exists and has binaries
- Verify `.zprofile` sources: `export PATH="$HOME/.local/bin:$PATH"`

**Python/pytest not found (neotest fails):**
- Ensure `pytest` is installed: `uv tool install pytest`
- Or use system package: `pip install pytest`

---

## Multi-Stage Custom Base

For internal Run:ai base images:

```dockerfile
# Stage 1: Your internal base with ML libraries
FROM registry.your-company.com/ai/ml-base:latest AS mlbase

# Stage 2: Dev env setup
FROM mlbase

# Install system packages (if not in base)
RUN dnf install -y zsh tmux git podman stow || true

# Create user matching your Run:ai setup
ARG USERNAME=jensen
ARG USER_UID=1000
RUN useradd --uid $USER_UID --create-home --shell /usr/bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME

# Copy dotfiles and tools from dev env image
COPY --from=ghcr.io/guylevavi/dotfiles-wsl:latest-ubi9 \
  /home/gl/.local/bin /home/$USERNAME/.local/bin
COPY --from=ghcr.io/guylevavi/dotfiles-wsl:latest-ubi9 \
  /home/gl/.config /home/$USERNAME/.config

# Fix ownership
RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME
ENV SHELL=/usr/bin/zsh PATH="/home/$USERNAME/.local/bin:$PATH"
CMD ["/usr/bin/zsh"]
```
