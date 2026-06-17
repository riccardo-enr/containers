# Testing Patterns

**Analysis Date:** 2026-06-17

## Current State

**There is no automated test suite in this repository.** No `tests/`
directory, no `*_test.py` / `test_*.py` files, no `conftest.py`, and no test
runner configured (`find` for test files returns nothing; `pyproject.toml`
declares no test dependencies or `[tool.pytest]` config).

`AGENTS.md` documents an *aspirational* pytest setup (`AGENTS.md:23-28,
103-109`) with all commands commented out. **Treat that as a TODO, not the
current reality.**

## What Plays the Role of Tests Today

Verification is done through **idempotent regeneration + git diff** and
**in-Dockerfile sanity checks**, not unit tests.

### 1. Drift check (`just check`)

The primary correctness gate. Regenerates every Dockerfile and fails if
`output/` differs from committed files (`justfile:94-99`):

```bash
just check
# uv run python generate.py --all --write
# git diff --exit-code -- output/   -> fails if stale
```

This guarantees `output/` always matches `config.yml` + `layers/*.j2`. Run it
in CI / pre-commit. After changing any layer or config, regenerate and commit.

### 2. CI build (`.github/workflows/build.yml`)

The real integration test: every target Dockerfile is actually built (and
pushed on `main`) via a GitHub Actions matrix. Triggered on changes to
`config.yml`, `generate.py`, `layers/**`, `templates/**`. A build failure is
the signal that a layer is broken.

- `generate` job renders all Dockerfiles and emits build/stack matrices from
  `generate.py --tags`.
- `build-base` then `build-stacks` jobs build each target with BuildKit + gha
  cache.

### 3. In-layer self-checks

Each tool-install layer ends with a `--version` invocation so the Docker build
**fails fast** if the install is broken
(`layers/nvim.j2:8`, `layers/code-agents.j2:10-12`). Preserve this pattern when
adding layers — it is the unit-test equivalent for this codebase.

### 4. StrictUndefined rendering guard

`generate.py` renders with `StrictUndefined` (`generate.py:51-57`), so a layer
referencing an undefined context variable errors at generation time rather than
producing a silently-wrong Dockerfile. `just gen` / `generate.py --all` thus
acts as a template smoke test.

## Run Commands

```bash
just check        # regenerate + fail on drift (closest thing to "test")
just gen          # render all targets to output/ (smoke-tests templates)
just render <t>   # render one target to stdout
./build.sh        # build all images locally (full integration)
just lint-md      # markdownlint-cli2 over *.md
```

## If Adding a Test Suite

`AGENTS.md` prescribes the intended approach should tests be added:

- **Runner:** `pytest`, with `tests/` directory and descriptive names
  `test_<function>_<expected_behavior>`.
- **Coverage:** `pytest --cov=containers --cov-report=term-missing` (note: the
  package name `containers` in `AGENTS.md` does not match the current flat
  `generate.py` module — target `generate` instead).
- **Mocking:** mock file I/O and network; use fixtures for shared setup.
- **High-value targets** (pure, side-effect-free, easy to unit test):
  `target_name`, `image_tag`, `resolve_target`, `build_order`,
  `find_target_by_name` in `generate.py`. These take plain dicts and return
  values, so they need no mocking.
- **Error-path tests:** assert `click.ClickException` is raised for unknown
  axis values, missing `base_stack`, and missing layer files
  (`generate.py:94-97, 118-122, 145-149`).

Add `pytest` to `pyproject.toml` dependencies (via `uv add --dev pytest`) and a
`just test` recipe before writing the first test.

## Coverage

**Requirements:** None enforced. No coverage tooling installed.

---

*Testing analysis: 2026-06-17*
