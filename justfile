# justfile - common tasks for the container image factory.
# Run `just` (or `just --list`) to see all recipes.

python := "uv run python"

# Container registry to push images to. Override on the CLI, e.g.
# `just registry=ghcr.io/other ghcr-push`.
registry := "ghcr.io/riccardo-enr"

# Show available recipes.
default:
    @just --list

# List configured targets (stack-distro-hardware).
list:
    {{python}} generate.py --list

# Show the local image tag for every target.
tags:
    {{python}} generate.py --tags

# Render a single target's Dockerfile to stdout (no write).
render target:
    {{python}} generate.py {{target}}

# Regenerate all Dockerfiles into output/.
gen:
    {{python}} generate.py --all --write

# Regenerate a single target into output/<target>/.
gen-one target:
    {{python}} generate.py {{target}} --write

# Build + tag every target as a local Docker image.
build:
    ./build.sh

# Build + tag a single target, e.g. `just build-one ros2-desktop-jazzy-gpu`.
build-one target:
    ./build.sh {{target}}

# Build only cpu targets.
build-cpu:
    ./build.sh --hardware cpu

# Build only gpu targets.
build-gpu:
    ./build.sh --hardware gpu

# Log in to ghcr.io using $GITHUB_TOKEN (a PAT with write:packages scope).
ghcr-login user=`git config user.name`:
    echo "${GITHUB_TOKEN:?set GITHUB_TOKEN to a PAT with write:packages}" \
        | docker login ghcr.io -u {{user}} --password-stdin

# Retag local images for `registry` and push them. With no arg, pushes every
# target; pass a target to push that target AND its base chain (deepest first),
# e.g. `just ghcr-push ros2-desktop-jazzy-gpu` also pushes ros2-base-jazzy-gpu.
ghcr-push target="":
    #!/usr/bin/env bash
    set -euo pipefail
    declare -A TAG BASE
    order=()
    while read -r name tag base; do
        [ -n "$tag" ] || continue
        TAG[$name]="$tag"; BASE[$name]="$base"
        order+=("$name")
    done < <({{python}} generate.py --tags)
    want=()
    if [ -n "{{target}}" ]; then
        [ -n "${TAG[{{target}}]:-}" ] \
            || { echo "no such target: {{target}}  (see: just list)" >&2; exit 1; }
        n="{{target}}"
        while [ -n "$n" ] && [ "$n" != "-" ]; do
            want=("$n" "${want[@]}")  # prepend: base ends up first
            n="${BASE[$n]:-}"
        done
    else
        want=("${order[@]}")
    fi
    for name in "${want[@]}"; do
        tag="${TAG[$name]}"
        remote="{{registry}}/$tag"
        echo ">> $tag -> $remote"
        docker tag "$tag" "$remote"
        docker push "$remote"
    done

# Build then push to `registry`. With no arg, releases every target; pass a
# target to release one, e.g. `just release ros2-desktop-jazzy-gpu`.
release target="":
    ./build.sh {{target}}
    just registry={{registry}} ghcr-push {{target}}

# Build + push every flavour of one stack, e.g. `just release-stack ros2-desktop`
# releases ros2-desktop-{jazzy,humble}-{cpu,gpu} (and each one's base chain).
release-stack stack:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$({{python}} generate.py --tags | awk '$1 ~ /^{{stack}}-/ {print $1}')
    [ -n "$targets" ] || { echo "no targets for stack: {{stack}}  (see: just list)" >&2; exit 1; }
    for t in $targets; do
        just registry={{registry}} release "$t"
    done

# Fail if output/ is stale vs config.yml + layers/ (use in CI / pre-commit).
check:
    {{python}} generate.py --all --write
    @git diff --exit-code -- output/ \
        || (echo "output/ is stale: commit the regenerated Dockerfiles" && exit 1)
    @echo "output/ is in sync."

# List the local images this repo produces.
images:
    docker images \
        --filter=reference='ros2-base:*' \
        --filter=reference='ros2-desktop:*' \
        --filter=reference='px4-sitl:*' \
        --filter=reference='devbox:*' \
        --format 'table {{{{.Repository}}:{{{{.Tag}}\t{{{{.Size}}'

# Lint all Markdown files (requires markdownlint-cli2).
lint-md:
    markdownlint-cli2

# Remove generated Dockerfiles.
clean:
    rm -rf output
