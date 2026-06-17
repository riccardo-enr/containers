# Codebase Concerns

**Analysis Date:** 2026-06-17

This repository is a template-based Dockerfile generator: `generate.py` renders
`layers/*.j2` Jinja fragments into `output/<target>/Dockerfile` per a
`(stack, distro, hardware)` matrix in `config.yml`; `build.sh` / `justfile`
build and push the resulting images. Concerns below are grouped by type.

## Tech Debt

**Stale `gpu-devel` hardware axis across consumer-facing files:**
- Issue: `config.yml` defines only `cpu` and `gpu` hardware axes (`config.yml:43-50`),
  but `build.sh` and the examples still reference a removed `gpu-devel` axis.
  The example base image `ros2-desktop:jazzy-gpu-devel` no longer exists.
- Files: `build.sh:12,15,18,44,103`, `examples/consumer.Dockerfile:5,15`,
  `examples/devcontainer-gpu.json:7`
- Impact: Anyone copying `examples/consumer.Dockerfile` or
  `examples/devcontainer-gpu.json` gets a `FROM ros2-desktop:jazzy-gpu-devel`
  that fails with "image not found". `build.sh --hardware gpu-devel` matches
  nothing and exits with an error. The `cpu|gpu|gpu-devel` help text is wrong.
- Fix approach: Either reintroduce a `gpu-devel` hardware entry in `config.yml`
  (and a target row), or sweep `build.sh` + `examples/*` to use `gpu`. Decide
  which is canonical and make all three consistent.

**Ineffective staleness gate in `just check`:**
- Issue: `output/` is gitignored (`.gitignore:7`) so no Dockerfiles are tracked
  (`git ls-files output/` returns nothing). The `check` recipe relies on
  `git diff --exit-code -- output/` (`justfile:97`), but `git diff` ignores
  untracked files, so the gate passes even when `output/` is stale or absent.
- Files: `justfile:95-99`, `.gitignore:7`
- Impact: The "fail if output/ is stale" safety net never fails. Drift between
  `config.yml` / `layers/` and committed Dockerfiles goes undetected by this
  recipe.
- Fix approach: Since `output/` is regenerated in CI anyway, drop the
  git-diff-based check, or compare against `git stash`/a temp render, or track
  `output/` and remove it from `.gitignore`. Pick one model (tracked vs.
  generated) and align `.gitignore`, `justfile:check`, and the header comment
  ("GENERATED FILE", `templates/dockerfile_header.j2:3`).

**`devbox` image family missing from image listings:**
- Issue: `build.sh` final summary and `justfile:images` filter only
  `ros2-base:*`, `ros2-desktop:*`, `px4-sitl:*` (`build.sh:110-113`,
  `justfile:103-108`). The `devbox` stack (`config.yml:103`) produces
  `devbox:*` images that never appear in either listing.
- Files: `build.sh:110-113`, `justfile:103-108`
- Impact: `devbox` images build but are invisible in the "Done. Local images"
  summary, misleading the user into thinking they were not built.
- Fix approach: Add `--filter=reference='devbox:*'` to both filter lists.

## Known Bugs

**`build_order` assumes single-level base_stack chaining:**
- Symptoms: `build_order` sorts targets into only two buckets (base vs. child)
  via a 0/1 key (`generate.py:184-187`). A grandchild stack (a `base_stack`
  that itself has a `base_stack`) could sort before its parent and fail the
  Docker `FROM`.
- Files: `generate.py:176-187`, documented constraint at `config.yml:56-58`
- Trigger: Add a stack whose `base_stack` is itself a child stack.
- Workaround: Convention only -- `config.yml:57` states "Chaining is one level
  deep". Not enforced in code; a topological sort would make it robust.

## Security Considerations

**Passwordless sudo baked into every image:**
- Risk: `user.j2` grants the `ros` user `NOPASSWD:ALL` (`layers/user.j2:16-17`).
  Numerous layers rely on this (`code-agents.j2:6`, `omz-shell.j2:3`,
  `px4-source.j2`). Any process running as `ros` has unrestricted root.
- Files: `layers/user.j2:16-17`, `examples/consumer.Dockerfile:24,31`
- Current mitigation: These are dev containers, not production images; the
  threat model is a single-user developer box.
- Recommendations: Acceptable for dev images, but document the assumption.
  Do not promote these images as production bases without removing the
  blanket NOPASSWD rule.

**Unpinned remote install scripts piped to a shell:**
- Risk: Several layers `curl ... | bash`/`| sh` from upstream `master` branches
  with no checksum or tag pin: NodeSource setup (`layers/nodejs.j2:5`),
  oh-my-zsh installer from `master` (`layers/omz-shell.j2:6`), ROS key from
  `rosdistro/master` (`layers/ros2-repo.j2:3`). A compromised upstream branch
  executes arbitrary code at build time.
- Files: `layers/nodejs.j2:5`, `layers/omz-shell.j2:6`, `layers/ros2-repo.j2:3`,
  `examples/consumer.Dockerfile:36-38`
- Current mitigation: HTTPS transport; trusted well-known sources.
- Recommendations: Where feasible, pin to a tagged URL and verify a checksum
  (as `nvim.j2`, `tmux.j2` already pin versions). At minimum, note the
  supply-chain exposure.

**`latest`-release resolution makes builds non-reproducible:**
- Risk: `just.j2` and `lazygit.j2` query the GitHub API `releases/latest` at
  build time (`layers/just.j2:6`, `layers/lazygit.j2:6`). The same Dockerfile
  produces different binaries on different days, and rate-limited/unauthenticated
  GitHub API calls can fail the build.
- Files: `layers/just.j2:6-10`, `layers/lazygit.j2:6-10`
- Current mitigation: This is an intentional "always latest" policy (see repo
  memory `install-latest-tool-versions.md`).
- Recommendations: Accepted trade-off, but be aware that BuildKit cache plus
  `latest` resolution means images can silently diverge from each other, and
  CI can break on GitHub API 403s. Consider an authenticated API call in CI.

## Performance Bottlenecks

**Repeated `generate.py --tags` invocations in CI:**
- Problem: The build workflow shells out to `uv run python generate.py --tags`
  four separate times per stack job (`.github/workflows/build.yml` tag/base
  resolution steps), each re-parsing config and re-rendering nothing but tags.
- Files: `.github/workflows/build.yml` (resolve-tag and resolve-base steps)
- Cause: Each step recomputes the full tag table to `awk` out one field.
- Improvement path: Resolve all needed fields once and pass via
  `$GITHUB_OUTPUT`. Minor; generation is fast.

**PX4 + agent builds compile from source in one giant layer:**
- Problem: `px4-source.j2` clones PX4 with `--recurse-submodules` and builds the
  Micro-XRCE-DDS-Agent superbuild (Fast-CDR/Fast-DDS) in two RUN steps
  (`layers/px4-source.j2:24-37`). This is the heaviest part of the build.
- Files: `layers/px4-source.j2`
- Cause: Source builds of large C++ projects.
- Improvement path: Acceptable for a base image cached by BuildKit; just be
  aware cold CI builds are long. The two-RUN split (default target then
  install) is required, not a mistake (`px4-source.j2:16-23`).

## Fragile Areas

**`user.j2` UID/GID remapping logic:**
- Files: `layers/user.j2:6-15`
- Why fragile: Branches on whether UID/GID 1000 already exists (ubuntu/CUDA
  bases differ), using `groupmod --new-name` / `usermod --login -m`. Edge cases
  (an existing group name colliding, home-dir move failures) are not handled.
- Safe modification: Test against every base family (`ubuntu:22.04`,
  `ubuntu:24.04`, `nvidia/cuda:*-devel-ubuntu22.04/24.04`) when changing.
- Test coverage: None.

**`build.sh` recursive `build_target` relies on associative arrays + word
splitting:**
- Files: `build.sh:62-95`
- Why fragile: Reads three space-separated columns from `generate.py --tags`
  into bash maps; recursion depends on the `-` sentinel and `set -euo pipefail`.
  A target name containing whitespace or a tags-format change silently breaks
  parsing. The `justfile:ghcr-push` recipe duplicates this same parsing logic
  (`justfile:58-86`), so the two can drift.
- Safe modification: Keep `generate.py --tags` output format stable; change
  both `build.sh` and `justfile:ghcr-push` together.
- Test coverage: None.

## Scaling Limits

**No automated tests anywhere:**
- Current capacity: Correctness is verified only by running `generate.py` and
  eyeballing output, plus full Docker builds in CI.
- Limit: As layers/stacks grow, regressions in `resolve_target` merge order
  (`generate.py:102-108`), `base_stack` resolution, or layer guards
  (`{% if ros_distro is defined %}`) are caught only by a full image build.
- Scaling path: Add lightweight unit tests (pytest) that render each target and
  assert on key invariants (base image, presence/absence of nvidia-env, ROS
  guards), plus a `hadolint` lint of generated Dockerfiles in CI.

## Dependencies at Risk

**External release URLs hard-coded to `x86_64` only:**
- Risk: `nvim.j2`, `tmux.j2`, `just.j2`, `lazygit.j2` all fetch
  `x86_64`/`amd64` artifacts (`layers/nvim.j2:5`, `layers/tmux.j2:6`,
  `layers/just.j2:8`, `layers/lazygit.j2:8`). The static tmux binary comes from
  a third-party repo (`mjakob-gh/build-static-tmux`), a single point of failure.
- Impact: Builds break on arm64 hosts; if `mjakob-gh/build-static-tmux`
  disappears, tmux installs fail with no fallback.
- Migration plan: Parameterize arch via a Jinja var; consider an apt fallback
  for tmux or vendoring the binary.

## Missing Critical Features

**No `just check` / generation-drift gate actually runs in CI:**
- Problem: `.github/workflows/build.yml` regenerates `output/` itself before
  building, so it never validates that a contributor's committed state is
  consistent -- and since `output/` is gitignored there is nothing to validate.
  There is no markdown-lint or Dockerfile-lint job either.
- Blocks: Catching config/layer mistakes before a full (slow) image build.

## Test Coverage Gaps

**Entire `generate.py` rendering pipeline is untested:**
- What's not tested: axis validation (`generate.py:89-97`), context merge order
  (`generate.py:102-109`), `base_stack` base/layer inheritance
  (`generate.py:116-134`), build ordering (`generate.py:176-187`), and the
  ROS-guard conditionals in layers.
- Files: `generate.py`, all `layers/*.j2`
- Risk: A layer referencing an undefined variable is caught by
  `StrictUndefined` only at render time for the specific target that exercises
  it; a target not in the `targets` list is never rendered and never checked.
- Priority: Medium -- a few render-and-assert pytest cases would cover most of
  the logic cheaply.

---

*Concerns audit: 2026-06-17*
