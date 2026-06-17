# Coding Conventions

**Analysis Date:** 2026-06-17

This repository is a template-based Dockerfile generator. Conventions span two
domains: **Python** (the `generate.py` CLI) and **Jinja2 layer templates**
(`layers/*.j2`, `templates/*.j2`). A normative style guide lives in `AGENTS.md`,
but the actual code in `generate.py` diverges from it in places (noted below);
match the **existing code**, not the aspirational guide.

## Naming Patterns

**Files:**
- Python: single module `generate.py` at repo root (no `containers/` package
  despite `AGENTS.md` referencing one).
- Jinja layers: lowercase, hyphen-separated, `.j2` extension matching the layer
  name used in `config.yml` (e.g. `layers/ros2-desktop.j2`, `layers/code-agents.j2`).
- Shell: lowercase `.sh` (`build.sh`).
- Generated output: `output/<stack>-<distro>-<hardware>/Dockerfile`.

**Functions (Python):**
- `snake_case`, short verb/noun phrases: `load_config`, `make_env`,
  `resolve_target`, `render_target`, `write_output`, `build_order`,
  `find_target_by_name`, `target_name`, `image_tag`.

**Variables (Python):**
- `snake_case`, concise: `stack`, `distro`, `hardware`, `context`, `layers`,
  `hw`, `stack_cfg`, `triples`, `base_stack`.

**Constants (Python):**
- `UPPER_CASE` module-level paths: `ROOT`, `CONFIG_PATH`, `LAYERS_DIR`,
  `TEMPLATES_DIR`, `OUTPUT_DIR`, `HEADER_TEMPLATE`. See `generate.py:29-35`.

**Jinja context variables:**
- `snake_case` (`profile_name`, `ros_distro`, `ubuntu_version`, `cuda_version`,
  `base`, `username`, `description`). Keys are merged from `config.yml`
  defaults/distro/hardware tables in `resolve_target` (`generate.py:102-109`).

## Code Style

**Formatting:**
- 4-space indentation, no tabs (PEP 8).
- Line length ~100 chars for code; `AGENTS.md` states max 100. Markdown is
  capped at 120 (`.markdownlint-cli2.yaml`, rule `MD013`).
- One blank line between functions, two not strictly enforced (file uses two
  blank lines between top-level functions in `generate.py`).

**Linting:**
- No Python linter configured. `AGENTS.md` lists flake8/black/ruff/mypy as
  commented-out TODOs (`AGENTS.md:14-28`); none are wired up in `pyproject.toml`.
- Markdown: `markdownlint-cli2` via `.markdownlint-cli2.yaml`, run with
  `just lint-md`. Excludes `output/`.

**Type hints:**
- `AGENTS.md` mandates type hints, but `generate.py` uses **none** — functions
  are untyped. Match the file: do not add type hints to existing functions
  unless doing a deliberate typing pass.

## Import Organization

Per `generate.py:22-27`, grouped stdlib -> third-party (no explicit local group
since it is a single module):

1. Standard library (`from pathlib import Path`)
2. Third-party (`click`, `yaml`, `jinja2`)

**Path aliases:** None. No package; imports are flat.

## Error Handling

**Patterns (the dominant convention — follow this):**
- CLI errors raise `click.ClickException(<message>)` with an actionable,
  lowercase message that lists valid alternatives. Examples:
  - Unknown axis value: `generate.py:94-97`
    (`f"unknown {axis} '{value}'. Available: {', '.join(sorted(table))}"`).
  - Missing layer file: `generate.py:145-149`.
  - Unknown `base_stack`: `generate.py:118-122`.
- Argument-shape errors (no target / no axes) raise `click.UsageError`
  (`generate.py:248-251`).
- Jinja `UndefinedError` is caught and re-raised as a `ClickException` that
  tells the user which config table to edit (`generate.py:152-156`).
- **Fail fast and loud:** the Jinja `Environment` uses `StrictUndefined`
  (`generate.py:51-57`) so a missing context variable errors rather than
  rendering empty. Preserve this when adding layers.
- Validate axis values **before** use (`resolve_target` checks all three axes up
  front, `generate.py:89-97`).

**Do not** use bare `except:`; catch specific exceptions (`UndefinedError`).

## Logging

**Framework:** None. User-facing output uses `click.echo(...)` to stdout
(`generate.py:220, 230, 261, 264-265`). Errors go through Click exceptions
(which print to stderr). Shell scripts echo to stderr with `>&2`.

## Comments (codedoc / literate style)

**Python:**
- Module-level triple-quoted docstring describing purpose + usage
  (`generate.py:2-20`).
- Every function has a triple-quoted docstring; multi-line for non-trivial logic
  (`make_env`, `resolve_target`, `image_tag`). Docstrings explain **why**, not
  just what (e.g. the `StrictUndefined` rationale, the merge-order comment).
- Inline `#` comments explain non-obvious decisions (the `base_stack` branch
  comment at `generate.py:111-115`, the merge-order note at `generate.py:102`).

**Jinja layers:**
- Each layer opens with a `# --- <name>: <one-line purpose> ----` banner
  comment (see `layers/bootstrap.j2:1`, `layers/nvim.j2:1`, `layers/code-agents.j2:1`).
- Follow with `#` prose comments explaining ordering dependencies and upstream
  quirks (e.g. nvim "apt nvim is ancient", code-agents "Needs the nodejs layer
  earlier in the stack").
- The generated header marks files `GENERATED FILE - do not edit by hand`
  (`templates/dockerfile_header.j2:3`).

**Shell:**
- Top-of-file block comment with purpose + usage examples (`build.sh:1-19`).

## Function Design

- Small, single-purpose functions; each does one transform
  (config load, env build, name derivation, render, write).
- Pure helpers (`target_name`, `image_tag`, `render_string`) are separated from
  side-effecting ones (`write_output`, `load_config`).
- Return tuples for compound results: `resolve_target` returns
  `(context, layers)` (`generate.py:135`).

## Module Design

- Single-module CLI. The `@click.command()` `main` is the only entry point,
  guarded by `if __name__ == "__main__":` (`generate.py:268-269`).
- No barrel files, no `__init__.py`, package mode disabled
  (`pyproject.toml: [tool.uv] package = false`).
- Run via `uv run python generate.py ...` or the `just` recipes (`justfile`).

## Click CLI Conventions

- Single `@click.command()` with one optional positional `target` plus flag
  options (`generate.py:198-213`).
- Every option has help text.
- Boolean modes are `is_flag=True` (`--all`, `--write`, `--dry-run`, `--list`,
  `--tags`); option dest renamed where the name collides with a builtin
  (`--all` -> `all_flag`, `--list` -> `list_flag`).
- Default behavior: if neither `--write` nor `--dry-run`, default to dry-run
  (`generate.py:253-254`).

## Jinja2 Template Conventions

- Templates live in `layers/` (composable snippets) and `templates/` (the
  header). Both dirs are on the loader path (`generate.py:52`).
- Environment options: `trim_blocks`, `lstrip_blocks`, `keep_trailing_newline`,
  `StrictUndefined` (`generate.py:51-57`). Write layers assuming whitespace
  control is on.
- Guard distro-specific lines behind `{% if ros_distro is defined %}` so layers
  compose onto non-ROS bases like `noble`
  (`templates/dockerfile_header.j2:13-15`).
- Keep logic minimal in templates; resolution/ordering lives in Python
  (`resolve_target`).
- Pin tool versions via `ARG <TOOL>_VERSION=...` inside the layer and verify the
  install with a `--version` check at the end of the `RUN`
  (`layers/nvim.j2:4-8`, `layers/code-agents.j2:10-12`).

  Note: per repo memory, prefer fetching the **latest** upstream release at
  build time over hard-pinning where practical.
- Always `rm -rf /var/lib/apt/lists/*` at the end of an apt `RUN`
  (`layers/bootstrap.j2:14`) and use `--no-install-recommends`.

## YAML Configuration

- `config.yml` is the single source of truth; commented section banners
  (`# --- Axis 1: ... ---`) separate axes (`config.yml`).
- `snake_case` keys; provide defaults via the `defaults` table consumed in
  `resolve_target` (`generate.py:104`).

## Commit Messages

- Conventional Commits enforced: `<type>(scope): subject` — types seen in
  history: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`. Recent examples:
  `feat(examples): bind-mount host github-copilot auth into devcontainers`,
  `feat(layers): add lazygit to dev stacks`.

---

*Convention analysis: 2026-06-17*
