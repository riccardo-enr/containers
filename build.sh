#!/usr/bin/env bash
#
# build.sh - build + tag every generated target as a LOCAL Docker image.
#
# Local images persist in your Docker daemon and are reusable from any other
# repo's devcontainer/Dockerfile (via "FROM <stack>:<distro>-<hardware>") with
# no rebuild. Re-run this only when you change a layer; BuildKit reuses
# unchanged layers so rebuilds are cheap.
#
# Usage:
#   ./build.sh                              # build all targets
#   ./build.sh ros2-desktop-jazzy-gpu-devel  # build a single target by name
#   ./build.sh --hardware cpu               # build only cpu targets
#   ./build.sh --hardware gpu               # build only gpu targets
#   ./build.sh --hardware gpu-devel         # build only gpu-devel targets
#
# Image naming comes from `generate.py --tags` (authoritative), e.g.
#   ros2-desktop-jazzy-gpu-devel  ->  ros2-desktop:jazzy-gpu-devel
#   px4-sitl-humble-cpu           ->  px4-sitl:humble-cpu

set -euo pipefail
cd "$(dirname "$0")"

export DOCKER_BUILDKIT=1

# Regenerate Dockerfiles so output/ matches config.yml + layers/.
uv run python generate.py --all --write >/dev/null

build_one() {
    local name="$1" tag="$2"
    local dir="output/${name}"
    [ -d "$dir" ] || { echo "no such target dir: $dir" >&2; return 1; }
    echo ">> building ${tag}  (from ${dir})"
    docker build -t "$tag" "$dir"
}

want=""
hw_filter=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hardware)
            hw_filter="${2:-}"
            [ -n "$hw_filter" ] || { echo "--hardware requires a value (cpu|gpu|gpu-devel)" >&2; exit 1; }
            shift 2
            ;;
        -*)
            echo "unknown option: $1  (see usage in header)" >&2; exit 1
            ;;
        *)
            want="$1"
            shift
            ;;
    esac
done

# `generate.py --tags` prints "<output-name> <image-tag> <base-target|->" per
# target, in build order (base images first). Load it into maps so we can build
# a target's base_stack image before the target itself (needed for the FROM).
names=()
declare -A TAG BASE BUILT
while read -r name tag base; do
    [ -n "$name" ] || continue
    names+=("$name")
    TAG["$name"]="$tag"
    BASE["$name"]="$base"
done < <(uv run python generate.py --tags)

build_target() {  # build a target's base chain first, then the target (once).
    local name="$1"
    [ -n "${BUILT[$name]:-}" ] && return 0
    local base="${BASE[$name]:-}"
    if [ -n "$base" ] && [ "$base" != "-" ]; then
        build_target "$base"
    fi
    build_one "$name" "${TAG[$name]}"
    BUILT["$name"]=1
}

# A target matches if it ends with -<hw_filter> (exact hardware suffix).
matches_hw() {
    local name="$1"
    [[ "$name" == *"-${hw_filter}" ]]
}

found=0
for name in "${names[@]}"; do
    if [ -n "$want" ]; then
        [ "$want" = "$name" ] || continue
    elif [ -n "$hw_filter" ]; then
        matches_hw "$name" || continue
    fi
    build_target "$name"
    found=1
done

if [ -n "$want" ] && [ "$found" -eq 0 ]; then
    echo "no such target: $want  (see: uv run python generate.py --list)" >&2
    exit 1
fi

if [ -n "$hw_filter" ] && [ "$found" -eq 0 ]; then
    echo "no targets matched hardware: $hw_filter  (valid: cpu, gpu, gpu-devel)" >&2
    exit 1
fi

echo
echo "Done. Local images:"
docker images \
    --filter=reference='ros2-base:*' \
    --filter=reference='ros2-desktop:*' \
    --filter=reference='px4-sitl:*' \
    --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
