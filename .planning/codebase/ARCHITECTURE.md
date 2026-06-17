<!-- refreshed: 2026-06-17 -->
# Architecture

**Analysis Date:** 2026-06-17

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    User / CI invocation                      │
├──────────────────┬──────────────────┬───────────────────────┤
│  generate.py CLI │    build.sh      │     justfile          │
│  `generate.py`   │   `build.sh`     │    `justfile`         │
│  (render)        │   (docker build) │   (task runner)       │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  │                     │
┌─────────────────────────────────────────────────────────────┐
│           Composition engine (generate.py)                   │
│  load_config -> resolve_target -> render_target              │
│  Jinja2 StrictUndefined env over layers/ + templates/        │
└────────┬───────────────────────────────┬────────────────────┘
         │                                │
         ▼                                ▼
┌──────────────────────┐      ┌────────────────────────────────┐
│  config.yml          │      │  templates/ + layers/*.j2       │
│  axes: distros /     │      │  dockerfile_header.j2 +         │
│  hardware / stacks / │      │  ordered layer snippets         │
│  defaults / targets  │      │                                 │
└──────────┬───────────┘      └────────────────┬───────────────┘
           │                                   │
           ▼                                   ▼
┌─────────────────────────────────────────────────────────────┐
│  output/<stack>-<distro>-<hardware>/Dockerfile (rendered)    │
│  -> docker build -> local image  <stack>:<distro>-<hardware> │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| CLI / orchestration | Parse args, select targets, drive render+write | `generate.py` (`main`) |
| Config loader | Parse `config.yml` into a dict | `generate.py` (`load_config`) |
| Jinja environment | Build `StrictUndefined` env over `layers/` + `templates/` | `generate.py` (`make_env`) |
| Context resolver | Merge axis vars into one render context, pick layer list | `generate.py` (`resolve_target`) |
| Renderer | Render header + ordered layers into one Dockerfile string | `generate.py` (`render_target`) |
| Build orderer | Sort targets so base_stack images build before children | `generate.py` (`build_order`) |
| Axis/stack data | Declare distros, hardware, stacks, defaults, targets | `config.yml` |
| Header template | Top-of-Dockerfile preamble (`FROM`, labels) | `templates/dockerfile_header.j2` |
| Layer snippets | Single-concern Dockerfile fragments | `layers/*.j2` |
| Image builder | `docker build` each target, base chain first | `build.sh` |
| Task runner | Wrap common generate/build/push flows | `justfile` |

## Pattern Overview

**Overall:** Template-composition pipeline (data-driven code generation). A
Dockerfile is the deterministic product of three orthogonal axes
(stack x distro x hardware) assembled from reusable Jinja2 fragments.

**Key Characteristics:**
- Three orthogonal axes composed via explicit `targets` list (not a full
  cartesian product) in `config.yml`.
- `StrictUndefined` Jinja env: a layer referencing an absent context variable
  fails loudly rather than rendering empty (`generate.py:44-57`).
- One-level stack inheritance via `base_stack`: a child stack builds `FROM`
  another stack's image and drops its hardware layers (`generate.py:116-127`).
- Generated `output/` is committed; `build.sh` regenerates before building so
  output always matches `config.yml` + `layers/`.

## Layers

**CLI / orchestration layer:**
- Purpose: Parse invocation, resolve which triples to render, write/print.
- Location: `generate.py` (`main`, lines 198-269)
- Contains: click command, target selection logic.
- Depends on: composition engine functions, `config.yml`.
- Used by: humans, `build.sh`, `justfile`.

**Composition engine layer:**
- Purpose: Turn (stack, distro, hardware) + config into Dockerfile text.
- Location: `generate.py` (`resolve_target`, `render_target`, lines 80-158)
- Contains: context merge, layer ordering, Jinja rendering.
- Depends on: `config.yml`, `layers/*.j2`, `templates/*.j2`.
- Used by: CLI layer.

**Data / template layer:**
- Purpose: Declare the axes and supply the Dockerfile fragments.
- Location: `config.yml`, `templates/`, `layers/`
- Contains: YAML axis tables, Jinja templates.
- Depends on: nothing (pure data).
- Used by: composition engine.

**Build layer:**
- Purpose: Build and tag local Docker images from rendered output.
- Location: `build.sh`, `justfile`
- Contains: BuildKit invocations, base-chain ordering, registry push.
- Depends on: `generate.py --tags`, `output/*/Dockerfile`, Docker daemon.
- Used by: humans, CI (`.github/workflows/build.yml`).

## Data Flow

### Primary Generation Path

1. Invocation parsed; targets resolved (`generate.py:213-251`).
2. `load_config()` parses `config.yml` (`generate.py:38-41`).
3. `make_env()` builds the Jinja env over `layers/` + `templates/` (`generate.py:44-57`).
4. `resolve_target()` merges defaults < distro vars < hardware args < axis labels into one context, then selects the layer list (hardware layers + stack layers, or just the delta for a `base_stack` child) (`generate.py:80-135`).
5. `render_target()` renders `dockerfile_header.j2` then each `layers/<name>.j2`, joining blocks (`generate.py:138-158`).
6. `write_output()` writes `output/<stack>-<distro>-<hardware>/Dockerfile`, or text is printed to stdout (`generate.py:161-167, 256-265`).

### Build Path

1. `build.sh` regenerates all output (`uv run python generate.py --all --write`).
2. `generate.py --tags` emits `<name> <image-tag> <base-target|->` in build order.
3. `build.sh` recursively builds each target's `base_stack` image first, then the target via `docker build -t <stack>:<distro>-<hardware>` (`build.sh:62-95`).

**State Management:**
- Stateless rendering: every run is a pure function of `config.yml` + templates.
- Persistent state lives in the local Docker daemon (built images) and the
  committed `output/` directory.

## Key Abstractions

**Axis (distro / hardware / stack):**
- Purpose: One orthogonal dimension of variation.
- Examples: `config.yml` tables `distros`, `hardware`, `stacks`.
- Pattern: Each axis value contributes vars/args/layers to the merged context.

**Target (triple):**
- Purpose: A concrete (stack, distro, hardware) build to produce.
- Examples: `config.yml` `targets` list; `target_name`, `image_tag` (`generate.py:60-72`).
- Pattern: Named `stack-distro-hardware`; tagged `stack:distro-hardware`.

**Layer:**
- Purpose: A single-concern Dockerfile fragment.
- Examples: `layers/bootstrap.j2`, `layers/user.j2`, `layers/nvidia-env.j2`.
- Pattern: Ordered list per stack; rendered with the merged context; ROS-only
  lines guarded by `{% if ros_distro is defined %}`.

**base_stack inheritance:**
- Purpose: Build one stack FROM another's image instead of a raw OS/CUDA base.
- Examples: `ros2-desktop` and `px4-sitl` set `base_stack: ros2-base`.
- Pattern: Child's `base` becomes the parent image tag; hardware layers dropped (`generate.py:116-127`).

## Entry Points

**`generate.py` CLI:**
- Location: `generate.py` (`main`)
- Triggers: `uv run generate.py ...`, called by `build.sh` and `justfile`.
- Responsibilities: list/tags/render/write Dockerfiles.

**`build.sh`:**
- Location: `build.sh`
- Triggers: manual, `just build`, CI.
- Responsibilities: regenerate output and build/tag local images in base order.

**`justfile`:**
- Location: `justfile`
- Triggers: `just <recipe>`.
- Responsibilities: thin wrappers over generate/build/push.

## Architectural Constraints

- **Threading:** Single-threaded, synchronous CLI; no concurrency.
- **Global state:** Module-level path constants `ROOT`, `CONFIG_PATH`, `LAYERS_DIR`, `TEMPLATES_DIR`, `OUTPUT_DIR` (`generate.py:29-33`). No mutable global state.
- **Circular imports:** None (single module + stdlib/third-party deps).
- **Stack chaining depth:** Exactly one level. A `base_stack` must itself be a plain (no-base_stack) stack and be listed as a target for every distro+hardware its children use (`config.yml:53-58`, `build_order` assumes single-level, `generate.py:176-187`).
- **GPU base:** GPU targets use the CUDA `-devel` image so CUDA code compiles in-container (`config.yml:9-15`).

## Anti-Patterns

### Editing files under output/ by hand

**What happens:** A rendered `output/<target>/Dockerfile` is edited directly.
**Why it's wrong:** Files are generated; `build.sh` runs `generate.py --all --write` before every build and overwrites them. The header marks them `GENERATED FILE - do not edit by hand` (`templates/dockerfile_header.j2`).
**Do this instead:** Edit the relevant `layers/*.j2` or `config.yml`, then regenerate.

### Referencing a context variable that no axis defines

**What happens:** A layer uses `{{ some_var }}` that no distro/hardware/defaults entry supplies.
**Why it's wrong:** `StrictUndefined` raises `UndefinedError`, failing the whole render (`generate.py:44-57, 152-156`).
**Do this instead:** Add the variable to `config.yml` (distros/hardware/defaults), or guard the line with `{% if var is defined %}` as ROS layers do (`layers/user.j2`).

### Repeating core layers in a child stack

**What happens:** A child stack re-lists `bootstrap`, `ros2-repo`, etc. already in its base.
**Why it's wrong:** Duplicates build steps and defeats `base_stack` reuse.
**Do this instead:** Set `base_stack` and list only the delta layers (`config.yml:71-98`).

## Error Handling

**Strategy:** Fail fast with `click.ClickException` / `click.UsageError` carrying
actionable messages.

**Patterns:**
- Unknown axis value lists available options (`generate.py:94-97`).
- Missing layer file names the exact path `layers/<name>.j2` (`generate.py:145-149`).
- Undefined Jinja variable is caught and re-raised with a hint to add it to config (`generate.py:152-156`).

## Cross-Cutting Concerns

**Logging:** `click.echo` for user-facing output; no logging framework.
**Validation:** Axis existence + base_stack existence checked at resolve time; Jinja `StrictUndefined` validates the context per layer.
**Authentication:** None in the generator; registry auth handled by Docker/`just ghcr-push`.

---

*Architecture analysis: 2026-06-17*
