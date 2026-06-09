# justfile - common tasks for the container image factory.
# Run `just` (or `just --list`) to see all recipes.

python := "uv run python"

# Container registry to push images to. Override on the CLI, e.g.
# `just registry=ghcr.io/other push`.
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
# target; pass a target to push one, e.g. `just ghcr-push ros2-desktop-jazzy-gpu`.
ghcr-push target="":
    #!/usr/bin/env bash
    set -euo pipefail
    pushed=0
    while read -r name tag base; do
        [ -n "$tag" ] || continue
        if [ -n "{{target}}" ] && [ "{{target}}" != "$name" ]; then continue; fi
        remote="{{registry}}/$tag"
        echo ">> $tag -> $remote"
        docker tag "$tag" "$remote"
        docker push "$remote"
        pushed=$((pushed + 1))
    done < <({{python}} generate.py --tags)
    if [ -n "{{target}}" ] && [ "$pushed" -eq 0 ]; then
        echo "no such target: {{target}}  (see: just list)" >&2
        exit 1
    fi

# Build then push to `registry`. With no arg, releases every target; pass a
# target to release one, e.g. `just release ros2-desktop-jazzy-gpu`.
release target="":
    ./build.sh {{target}}
    just registry={{registry}} ghcr-push {{target}}

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
