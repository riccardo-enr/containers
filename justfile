# justfile - common tasks for the container image factory.
# Run `just` (or `just --list`) to see all recipes.

python := "python3"

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

# Build + tag a single target, e.g. `just build-one ros2-desktop-jazzy-gpu-devel`.
build-one target:
    ./build.sh {{target}}

# Fail if output/ is stale vs config.yml + layers/ (use in CI / pre-commit).
check:
    {{python}} generate.py --all --write
    @git diff --exit-code -- output/ \
        || (echo "output/ is stale: commit the regenerated Dockerfiles" && exit 1)
    @echo "output/ is in sync."

# List the local images this repo produces.
images:
    docker images \
        --filter=reference='ros2-desktop:*' \
        --filter=reference='px4-sitl:*' \
        --format 'table {{{{.Repository}}:{{{{.Tag}}\t{{{{.Size}}'

# Remove generated Dockerfiles.
clean:
    rm -rf output
