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
#   ./build.sh                          # generate + build all targets
#   ./build.sh ros2-desktop-jazzy-gpu-devel   # build a single target by name
#
# Image naming comes from `generate.py --tags` (authoritative), e.g.
#   ros2-desktop-jazzy-gpu-devel  ->  ros2-desktop:jazzy-gpu-devel
#   px4-sitl-humble-cpu           ->  px4-sitl:humble-cpu

set -euo pipefail
cd "$(dirname "$0")"

export DOCKER_BUILDKIT=1

# Regenerate Dockerfiles so output/ matches config.yml + layers/.
python3 generate.py --all --write >/dev/null

build_one() {
    local name="$1" tag="$2"
    local dir="output/${name}"
    [ -d "$dir" ] || { echo "no such target dir: $dir" >&2; return 1; }
    echo ">> building ${tag}  (from ${dir})"
    docker build -t "$tag" "$dir"
}

want="${1:-}"
found=0

# `generate.py --tags` prints "<output-name> <image-tag>" per target.
while read -r name tag; do
    [ -n "$name" ] || continue
    if [ -z "$want" ] || [ "$want" = "$name" ]; then
        build_one "$name" "$tag"
        found=1
    fi
done < <(python3 generate.py --tags)

if [ -n "$want" ] && [ "$found" -eq 0 ]; then
    echo "no such target: $want  (see: python3 generate.py --list)" >&2
    exit 1
fi

echo
echo "Done. Local images:"
docker images --filter=reference='ros2-desktop:*' --filter=reference='px4-sitl:*' \
    --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
