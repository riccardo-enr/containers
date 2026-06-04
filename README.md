# Containers

[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![ROS](https://img.shields.io/badge/ROS-22314E?logo=ros&logoColor=white)](https://www.ros.org/)
[![PX4](https://img.shields.io/badge/PX4-1B2A4E?logo=px4&logoColor=white)](https://px4.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)

Template-based container configuration generator. Composes Dockerfiles from
small, reusable Jinja2 layer snippets along three orthogonal axes.

## Installation

```bash
pixi install        # or: pip install -r requirements.txt
```

Dependencies: Jinja2, PyYAML, click.

## Usage

```bash
python generate.py --list                       # list configured targets
python generate.py ros2-desktop-humble-cpu      # render a target to stdout
python generate.py ros2-desktop-jazzy-gpu --write  # -> output/.../Dockerfile
python generate.py --all --write                # regenerate every target

# ad-hoc combo that need not be in the targets list:
python generate.py --stack px4-sitl --distro humble --hardware gpu
```

## Three axes

A Dockerfile is the product of three independent choices:

| Axis         | Values                     | Controls                               |
|--------------|----------------------------|----------------------------------------|
| **distro**   | `jazzy`, `humble`          | `ros_distro` + its Ubuntu/CUDA pairing |
| **hardware** | `cpu`, `gpu`               | base-image family + GPU-only layers    |
| **stack**    | `ros2-desktop`, `px4-sitl` | the ordered layer recipe               |

A **target** is one `(stack, distro, hardware)` triple. The base image is a
function of *both* distro and hardware:

```text
cpu -> ubuntu:<ubuntu_version>
gpu -> nvidia/cuda:<cuda_version>-runtime-ubuntu<ubuntu_version>
```

CUDA/Ubuntu pairings are not symmetric: Noble (24.04) needs CUDA >= 12.5, so
`cuda_version` lives on the **distro** axis (`12.6.3` covers both 22.04/24.04).

`targets:` in `config.yml` lists exactly which triples to build, so you avoid
an unwanted full 2x2x2 product. Default coverage: `ros2-desktop` on all four
distro x hardware cells, plus `px4-sitl` CPU-only.

## How it works

```text
config.yml        distros + hardware + stacks + targets
layers/*.j2       one Jinja2 snippet per logical Dockerfile block
templates/        the Dockerfile header (FROM, ENV, ARG)
generate.py       merges axis context, renders header + hw layers + stack layers
output/<stack>-<distro>-<hardware>/Dockerfile   generated, do-not-edit result
```

Layers are parametric on the merged context: `ros2-desktop.j2` uses
`{{ ros_distro }}`, `ros2-repo.j2` uses `{{ ubuntu_codename }}`. Some layers
are **distro-aware** where behaviour genuinely differs -- e.g.
`mavsdk-python.j2` only passes `pip --break-system-packages` on Noble (24.04),
which enforces PEP 668; Jammy's older pip neither has nor needs it.

Rendering uses Jinja2 `StrictUndefined`: a layer referencing a variable absent
from the merged context fails loudly instead of emitting an empty string.

### Extending

- **New distro** (e.g. `rolling`): add an entry under `distros:` with its
  `ros_distro` / `ubuntu_codename` / `ubuntu_version` / `cuda_version`.
- **New stack**: add an entry under `stacks:` with an ordered `layers:` list.
- **New layer**: drop `layers/<name>.j2` in and reference it from a stack or
  the hardware axis.
- **New target**: add a `{ stack, distro, hardware }` line under `targets:`.

## License

MIT License - see [LICENSE](LICENSE) for details.
