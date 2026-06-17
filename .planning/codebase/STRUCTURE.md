# Codebase Structure

**Analysis Date:** 2026-06-17

## Directory Layout

```
containers/
├── generate.py          # CLI + composition engine (single-module core)
├── config.yml           # Axis tables: distros, hardware, stacks, defaults, targets
├── build.sh             # Regenerate output + docker build/tag all targets
├── justfile             # Task-runner wrappers over generate/build/push
├── pyproject.toml       # Python project + deps (jinja2, pyyaml, click)
├── uv.lock              # Pinned dependency lockfile (uv)
├── layers/              # Jinja2 Dockerfile fragments, one concern per file
├── templates/           # dockerfile_header.j2 (shared preamble)
├── examples/            # consumer.Dockerfile + devcontainer JSON samples
├── output/              # GENERATED: output/<target>/Dockerfile per target
├── .github/workflows/   # build.yml CI pipeline
├── README.md            # Usage + three-axes explanation
└── AGENTS.md            # Agent/contributor guidance
```

## Directory Purposes

**`layers/`:**
- Purpose: Reusable, single-concern Dockerfile snippets composed per stack.
- Contains: 21 `*.j2` files (e.g. `bootstrap.j2`, `nodejs.j2`, `ros2-repo.j2`, `user.j2`, `nvidia-env.j2`, `px4-source.j2`, `code-agents.j2`).
- Key files: `bootstrap.j2` (base packages/locale), `user.j2` (non-root user, ROS sourcing), `nvidia-env.j2` (GPU runtime env).

**`templates/`:**
- Purpose: Top-level Dockerfile scaffolding rendered before any layer.
- Contains: `dockerfile_header.j2`.
- Key files: `templates/dockerfile_header.j2` (syntax directive, generated-file banner, `FROM`, profile label).

**`output/`:**
- Purpose: Rendered, committed Dockerfiles, one subdir per target.
- Contains: `output/<stack>-<distro>-<hardware>/Dockerfile` (14 targets).
- Generated: Yes (by `generate.py --all --write`). Do not edit by hand.

**`examples/`:**
- Purpose: Show how a downstream repo consumes a built image.
- Contains: `consumer.Dockerfile`, `devcontainer-cpu.json`, `devcontainer-gpu.json`.

**`.github/workflows/`:**
- Purpose: CI.
- Contains: `build.yml`.

## Key File Locations

**Entry Points:**
- `generate.py`: render Dockerfiles from axes (CLI).
- `build.sh`: build + tag local images.
- `justfile`: task recipes (`just list`, `just build`, `just ghcr-push`).

**Configuration:**
- `config.yml`: all axis data and target list (the single source of truth).
- `pyproject.toml` / `uv.lock`: Python deps and pins.
- `.markdownlint-cli2.yaml`: markdown lint config.

**Core Logic:**
- `generate.py` (`resolve_target`, `render_target`, `build_order`).

**Testing:**
- No test suite present. Validation is runtime (`StrictUndefined`) + CI build.

## Naming Conventions

**Files:**
- Layer fragments: `layers/<concern>.j2`, lowercase, hyphenated (e.g. `fzf-shell.j2`, `mavsdk-python.j2`).
- Generated dirs: `output/<stack>-<distro>-<hardware>/`.

**Targets / images:**
- Target name: `stack-distro-hardware` (e.g. `ros2-desktop-jazzy-gpu`).
- Image tag: `stack:distro-hardware` (e.g. `ros2-desktop:jazzy-gpu`) — authoritative from `image_tag` (`generate.py:65-72`), not parsed from dir name.

**Stack / axis values:**
- Lowercase, hyphenated stacks (`ros2-base`, `ros2-desktop`, `px4-sitl`, `devbox`).
- Distro = ROS distro name or bare Ubuntu codename (`jazzy`, `humble`, `noble`).
- Hardware = `cpu` | `gpu`.

**Python:** PEP 8 snake_case functions; module-level `UPPER_CASE` path constants; functions carry triple-quoted docstrings (codedoc style).

## Where to Add New Code

**New tool/feature in images:**
- Create a layer: `layers/<name>.j2` (guard ROS-only lines with `{% if ros_distro is defined %}`).
- Add `<name>` to the relevant stack's `layers` list in `config.yml`.

**New stack:**
- Add an entry under `stacks:` in `config.yml` (optionally `base_stack`), then add `targets` triples. Regenerate with `uv run generate.py --all --write`.

**New distro or hardware variant:**
- Add an entry under `distros:` or `hardware:` in `config.yml`, then add targets.

**New context variable:**
- Add it under `defaults`, a `distros` entry, or a `hardware` `args` block so `StrictUndefined` resolves it.

**Build/CI tweaks:**
- `build.sh` for local build behaviour; `.github/workflows/build.yml` for CI; `justfile` for new task recipes.

## Special Directories

**`output/`:**
- Purpose: Rendered Dockerfiles per target.
- Generated: Yes. Committed: Yes (kept in sync with config/layers).

**`.venv/`:**
- Purpose: uv-managed virtualenv.
- Generated: Yes. Committed: No (gitignored).

**`.planning/`:**
- Purpose: GSD planning + codebase maps.
- Generated: Partly (these documents). Committed: Yes.

---

*Structure analysis: 2026-06-17*
