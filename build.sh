#!/usr/bin/env bash
#
# build.sh - build + tag every generated target as a LOCAL Docker image.
#
# Local images persist in your Docker daemon and are reusable from any other
# repo's devcontainer (via "image": "<stack>:<distro>-<hardware>") with no
# rebuild. Re-run this only when you change a layer; BuildKit reuses unchanged
# layers so rebuilds are cheap.
#
# Usage:
#   ./build.sh                 # generate + build all targets
#   ./build.sh ros2-desktop-jazzy-gpu   # build a single target by name
#
# Image naming: target "<stack>-<distro>-<hardware>" -> "<stack>:<distro>-<hardware>"
#   ros2-desktop-jazzy-gpu  ->  ros2-desktop:jazzy-gpu
#   px4-sitl-humble-cpu     ->  px4-sitl:humble-cpu

set -euo pipefail
cd "$(dirname "$0")"

export DOCKER_BUILDKIT=1

# Regenerate Dockerfiles so output/ matches config.yml + layers/.
python3 generate.py --all --write >/dev/null

# Map an output dir name to "<stack>:<distro>-<hardware>".
# The last two dash-separated tokens are distro and hardware; the rest is the
# stack (stack names themselves contain dashes, e.g. ros2-desktop).
image_tag() {
    local name="$1"
    local hardware="${name##*-}"        # after last dash
    local rest="${name%-*}"             # strip hardware
    local distro="${rest##*-}"          # after new last dash
    local stack="${rest%-*}"            # strip distro
    echo "${stack}:${distro}-${hardware}"
}

build_one() {
    local name="$1"
    local dir="output/${name}"
    [ -d "$dir" ] || { echo "no such target: $name" >&2; exit 1; }
    local tag
    tag="$(image_tag "$name")"
    echo ">> building ${tag}  (from ${dir})"
    docker build -t "$tag" "$dir"
}

if [ "$#" -ge 1 ]; then
    build_one "$1"
else
    for dir in output/*/; do
        build_one "$(basename "$dir")"
    done
fi

echo
echo "Done. Local images:"
docker images --filter=reference='ros2-desktop:*' --filter=reference='px4-sitl:*' \
    --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
