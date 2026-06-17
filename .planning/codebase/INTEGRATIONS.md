# External Integrations

**Analysis Date:** 2026-06-17

This is a Dockerfile generator. It has no runtime application integrations
(no database, no auth provider, no application APIs). Its "integrations" are
the external package repositories, GitHub release endpoints, and the container
registry/CI it pulls from and pushes to. All are reached at *build time*.

## APIs & External Services

**Build-time package repositories & download endpoints:**
- ROS 2 apt repo - `http://packages.ros.org/ros2/ubuntu`; key from `https://raw.githubusercontent.com/ros/rosdistro/master/ros.key` (`layers/ros2-repo.j2`)
- NodeSource 22.x setup script - `https://deb.nodesource.com/setup_22.x` (`layers/nodejs.j2`)
- GitHub Releases (prebuilt binaries):
  - Neovim - `github.com/neovim/neovim/releases` (pinned `0.12.2`, `layers/nvim.j2`)
  - tmux static - `github.com/mjakob-gh/build-static-tmux/releases` (pinned `3.6b`, `layers/tmux.j2`)
  - lazygit - `github.com/jesseduffield/lazygit/releases/latest` (`layers/lazygit.j2`)
  - just - `github.com/casey/just/releases/latest` (`layers/just.j2`)
- GitHub API (latest-release tag resolution) - `https://api.github.com/repos/{jesseduffield/lazygit,casey/just}/releases/latest` (`layers/lazygit.j2`, `layers/just.j2`); unauthenticated, subject to rate limits
- GitHub source clone - `https://github.com/px4/PX4-Autopilot.git` (`--branch v1.17.0`) and Micro-XRCE-DDS-Agent `v3.0.1` (`layers/px4-source.j2`)
- npm registry (AI agent CLIs) - `@anthropic-ai/claude-code`, `@openai/codex`, `opencode-ai` (`layers/code-agents.j2`)
- PyPI (pip) - `mavsdk`, `aioconsole`, `pymavlink`, `ruff` (`layers/mavsdk-python.j2`, `layers/ruff.j2`)
- Ubuntu apt + NVIDIA CUDA base images (Docker Hub) - `ubuntu:<ver>`, `nvidia/cuda:<ver>-devel-ubuntu<ver>` (`config.yml`)

## Data Storage

**Databases:**
- None - not an application

**File Storage:**
- Local filesystem only - generated Dockerfiles under `output/<target>/Dockerfile`

**Caching:**
- BuildKit layer cache (local) via `DOCKER_BUILDKIT=1`
- GitHub Actions cache for builds - `cache-from`/`cache-to: type=gha,scope=<target>` (`.github/workflows/build.yml`)

## Authentication & Identity

**Auth Provider:**
- None at the application level

**Build/publish auth:**
- GHCR login uses `GITHUB_TOKEN` (PAT with `write:packages`) - `just ghcr-login`, `justfile`
- In CI, `docker/login-action@v3` authenticates to GHCR with `${{ secrets.GITHUB_TOKEN }}` and `${{ github.actor }}` (`.github/workflows/build.yml`)

**In-image identity:**
- Produced images create a non-root `ros` user (uid/gid 1000) with NOPASSWD sudo (`layers/user.j2`)

## Monitoring & Observability

**Error Tracking:**
- None

**Logs:**
- Generator echoes progress via Click (`generate.py`); `build.sh` echoes build steps. No structured logging.

## CI/CD & Deployment

**Hosting / Registry:**
- GitHub Container Registry - `ghcr.io/<owner>`; local push default `ghcr.io/riccardo-enr` (`justfile`)

**CI Pipeline:**
- GitHub Actions - `.github/workflows/build.yml`
  - Triggers: push/PR to `main` touching `config.yml`, `generate.py`, `layers/**`, `templates/**`; plus `workflow_dispatch`
  - Jobs: `generate` (render + emit base/stack matrices via `generate.py --tags` + `jq`), `build-base`, `build-stacks`
  - Actions used: `actions/checkout@v4`, `astral-sh/setup-uv@v5`, `actions/upload-artifact@v4` / `download-artifact@v4`, `docker/login-action@v3`, `docker/setup-buildx-action@v3`, `docker/build-push-action@v6`
  - Push to registry only on `main` (`push: github.event_name != 'pull_request'`)
  - Stack builds inject the prebuilt base via `build-contexts` (`docker-image://...`) so bases are not rebuilt

## Environment Configuration

**Required env vars (tooling):**
- `GITHUB_TOKEN` - GHCR push (local `just ghcr-login`)
- `DOCKER_BUILDKIT=1` - set automatically by `build.sh`
- CI: `REGISTRY=ghcr.io`, `OWNER=${{ github.repository_owner }}`, `secrets.GITHUB_TOKEN`

**Secrets location:**
- GitHub Actions secrets (`GITHUB_TOKEN`, auto-provided). No `.env` or secrets files in the repo.

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None (GitHub Actions triggers are repo events, not external webhooks)

## Notes for Consumers

Downstream projects integrate by building `FROM` a factory image
(`examples/consumer.Dockerfile`) or referencing it in a devcontainer
(`examples/devcontainer-cpu.json`, `examples/devcontainer-gpu.json`). GPU
devcontainers pass `--gpus all` and bind-mount host `~/.config/nvim` and
`~/.config/github-copilot` into the `ros` user's home.

---

*Integration audit: 2026-06-17*
