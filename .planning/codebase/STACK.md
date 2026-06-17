# Technology Stack

**Analysis Date:** 2026-06-17

This repository is a template-based Dockerfile *generator* (an "image factory"),
not an application. It composes ROS 2 / PX4 / devbox container images from
orthogonal Jinja2 layers. The "stack" is therefore split between the generator
tooling (Python) and the technologies baked into the *produced* images (ROS 2,
PX4, CUDA, terminal tooling).

## Languages

**Primary:**
- Python `>=3.9` (pinned to 3.11 in `.venv`) - the Dockerfile generator (`generate.py`)
- Jinja2 templates (`.j2`) - the layer/header recipes in `layers/` and `templates/`
- Bash - build orchestration (`build.sh`, `justfile` shell recipes)

**Secondary:**
- YAML - configuration (`config.yml`, `.github/workflows/build.yml`, `.markdownlint-cli2.yaml`)
- Dockerfile - generated output (`output/<target>/Dockerfile`) and the example `examples/consumer.Dockerfile`

## Runtime

**Environment:**
- CPython 3.11 (local `.venv`); declared minimum `requires-python = ">=3.9"` in `pyproject.toml`
- Docker with BuildKit (`DOCKER_BUILDKIT=1` set in `build.sh`); Dockerfiles use `# syntax=docker/dockerfile:1`

**Package Manager:**
- `uv` (astral-sh) - manages the Python environment; invoked as `uv run python ...`
- Lockfile: present (`uv.lock`, 54 KB). `[tool.uv] package = false` - project is not installable, run as scripts.

## Frameworks

**Core:**
- Jinja2 `3.1.6` - template engine; `Environment` configured with `StrictUndefined`, `trim_blocks`, `lstrip_blocks` in `generate.py:44-57`
- Click `8.4.1` - CLI framework for `generate.py` (commands/options/flags)
- PyYAML `6.0.3` - parses `config.yml` (`generate.py:38-41`)

**Testing:**
- Not detected - no test framework, no test files in the repo

**Build/Dev:**
- `just` (justfile) `>=` - task runner; recipes for `list/tags/render/gen/build/release/check/lint-md/clean`
- `build.sh` - Bash build orchestrator; renders Dockerfiles then `docker build` in dependency order
- `markdownlint-cli2` - Markdown linting (`just lint-md`, config `.markdownlint-cli2.yaml`)

## Key Dependencies

**Critical (generator):**
- `jinja2` - all Dockerfile layers are Jinja templates; absent variables fail loudly via `StrictUndefined`
- `pyyaml` - the single source of truth `config.yml` is YAML
- `click` - the entire CLI surface

**Baked into produced images (not Python deps):**
- ROS 2 `jazzy` (Ubuntu 24.04 noble) and `humble` (Ubuntu 22.04 jammy) - `layers/ros2-desktop.j2`, `config.yml`
- CUDA `12.6.3` devel base for GPU targets (`nvidia/cuda:12.6.3-devel-ubuntu<ver>`) - `config.yml:48`
- PX4-Autopilot `v1.17.0` + Micro-XRCE-DDS-Agent `v3.0.1` - `layers/px4-source.j2`
- MAVSDK / pymavlink / aioconsole (pip) - `layers/mavsdk-python.j2`
- Gazebo via `ros-<distro>-ros-gz` (Harmonic on Jazzy, Fortress on Humble) - `layers/gz-sim.j2`
- Node.js 22.x LTS (NodeSource) - `layers/nodejs.j2`
- Neovim `0.12.2`, tmux `3.6b`, lazygit (latest), just (latest), fzf/ripgrep/fd, clangd, ruff, zsh+oh-my-zsh
- AI coding agents (npm): `@anthropic-ai/claude-code`, `@openai/codex`, `opencode-ai` - `layers/code-agents.j2`

**Infrastructure:**
- NVIDIA Container Toolkit (runtime) - GPU images set `NVIDIA_VISIBLE_DEVICES=all` / `NVIDIA_DRIVER_CAPABILITIES=all` (`layers/nvidia-env.j2`); consumed via `docker run --gpus all`

## Configuration

**Single source of truth:** `config.yml`
- Three orthogonal axes: `distros` (jazzy/humble/noble), `hardware` (cpu/gpu), `stacks` (ros2-base/ros2-desktop/px4-sitl/devbox)
- `targets:` lists the explicit (stack, distro, hardware) triples to generate (not the full cartesian product)
- `defaults:` holds shared template vars (e.g. `username: ros`)
- Context merge order (`generate.py:102-109`): defaults < distro vars < hardware args < axis labels
- `base_stack` allows a stack to build FROM another stack's image (one level deep)

**Build:**
- `pyproject.toml` - Python project metadata + deps
- `justfile` - task recipes; `registry := "ghcr.io/riccardo-enr"` is the push target
- `build.sh` - local build order resolution from `generate.py --tags`
- Generated `output/<target>/Dockerfile` - committed; `just check` fails CI if stale vs config/layers

**Environment variables (tooling):**
- `GITHUB_TOKEN` - PAT with `write:packages` for `just ghcr-login` / `ghcr-push`
- `DOCKER_BUILDKIT=1` - set by `build.sh`
- No `.env` file present in the repo

## Platform Requirements

**Development:**
- Linux x86_64 (layers download `x86_64`/`amd64` prebuilt binaries: nvim, tmux, lazygit, just)
- `uv`, Docker + BuildKit, `just` (optional), `docker` daemon access

**Production (image consumers):**
- Container registry: GitHub Container Registry (`ghcr.io/<owner>`)
- GPU images require an NVIDIA GPU + NVIDIA Container Toolkit on the host (`--gpus all`)
- CPU images fall back to Mesa llvmpipe software rendering for Gazebo (`LIBGL_ALWAYS_SOFTWARE=1`)
- Intended consumption pattern: downstream repos `FROM` a factory image (see `examples/consumer.Dockerfile`, `examples/devcontainer-*.json`)

---

*Stack analysis: 2026-06-17*
