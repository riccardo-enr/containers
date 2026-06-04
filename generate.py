#!/usr/bin/env python3
"""
generate.py - compose Dockerfiles from three orthogonal axes.

A target is a (stack, distro, hardware) triple:

    stack    -> the ordered layer recipe          (config.yml: stacks)
    distro   -> ROS distro + Ubuntu/CUDA pairing   (config.yml: distros)
    hardware -> base image family + GPU-only layers (config.yml: hardware)

The merged template context is rendered through templates/dockerfile_header.j2
followed by the hardware layers and then the stack's layers, each from
layers/<name>.j2. Output goes to output/<stack>-<distro>-<hardware>/Dockerfile.

Usage:
    python generate.py --list
    python generate.py ros2-desktop-humble-cpu            # named target
    python generate.py --stack ros2-desktop --distro humble --hardware cpu
    python generate.py --all --write
"""

from pathlib import Path

import click
import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined
from jinja2.exceptions import UndefinedError

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "config.yml"
LAYERS_DIR = ROOT / "layers"
TEMPLATES_DIR = ROOT / "templates"
OUTPUT_DIR = ROOT / "output"

HEADER_TEMPLATE = "dockerfile_header.j2"


def load_config():
    """Parse config.yml into a dict."""
    with CONFIG_PATH.open() as fh:
        return yaml.safe_load(fh)


def make_env():
    """
    Jinja2 environment searching layers/ and templates/.

    StrictUndefined makes a layer that references a variable absent from the
    merged context fail loudly rather than silently rendering empty.
    """
    return Environment(
        loader=FileSystemLoader([str(LAYERS_DIR), str(TEMPLATES_DIR)]),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def target_name(stack, distro, hardware):
    """Canonical name / output directory for a target."""
    return f"{stack}-{distro}-{hardware}"


def image_tag(stack, distro, hardware):
    """
    Local Docker image tag for a target: "<stack>:<distro>-<hardware>".

    Emitted authoritatively here (not parsed from the dir name) because both
    stack and hardware may contain dashes (e.g. ros2-desktop, gpu-devel).
    """
    return f"{stack}:{distro}-{hardware}"


def render_string(env, template_str, context):
    """Render an inline Jinja string (used for base image + description)."""
    return env.from_string(template_str).render(**context)


def resolve_target(config, env, stack, distro, hardware):
    """
    Build the full template context for one (stack, distro, hardware) triple,
    validating that each axis value exists.
    """
    distros = config.get("distros", {})
    hardwares = config.get("hardware", {})
    stacks = config.get("stacks", {})

    for axis, value, table in (
        ("distro", distro, distros),
        ("hardware", hardware, hardwares),
        ("stack", stack, stacks),
    ):
        if value not in table:
            raise click.ClickException(
                f"unknown {axis} '{value}'. Available: {', '.join(sorted(table))}"
            )

    hw = hardwares[hardware]

    # Merge order: defaults < distro vars < hardware args < axis labels.
    context = {}
    context.update(config.get("defaults", {}))
    context.update(distros[distro])
    context.update(hw.get("args", {}))
    context["distro"] = distro
    context["hardware"] = hardware
    context["profile_name"] = target_name(stack, distro, hardware)

    # base and description are themselves templated.
    context["base"] = render_string(env, hw["base"], context)
    context["description"] = render_string(
        env, stacks[stack].get("description", ""), context
    )

    # Hardware layers go first (e.g. nvidia-env), then the stack recipe.
    layers = list(hw.get("layers", [])) + list(stacks[stack].get("layers", []))
    return context, layers


def render_target(config, env, stack, distro, hardware):
    """Render the full Dockerfile text for one target."""
    context, layers = resolve_target(config, env, stack, distro, hardware)

    blocks = [env.get_template(HEADER_TEMPLATE).render(**context)]
    for layer in layers:
        path = LAYERS_DIR / f"{layer}.j2"
        if not path.exists():
            raise click.ClickException(
                f"target '{context['profile_name']}' references missing "
                f"layer file 'layers/{layer}.j2'"
            )
        try:
            blocks.append(env.get_template(f"{layer}.j2").render(**context))
        except UndefinedError as exc:
            raise click.ClickException(
                f"layer '{layer}' in target '{context['profile_name']}': "
                f"{exc.message}. Add it to config.yml (distros/hardware/defaults)."
            )

    return "\n\n".join(block.rstrip("\n") for block in blocks) + "\n"


def write_output(name, text):
    """Write rendered text to output/<name>/Dockerfile."""
    dest_dir = OUTPUT_DIR / name
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / "Dockerfile"
    dest.write_text(text)
    return dest


def all_targets(config):
    """Yield (stack, distro, hardware) for every configured target."""
    for t in config.get("targets", []):
        yield t["stack"], t["distro"], t["hardware"]


def find_target_by_name(config, name):
    """Map a 'stack-distro-hardware' string back to its triple."""
    for stack, distro, hardware in all_targets(config):
        if target_name(stack, distro, hardware) == name:
            return stack, distro, hardware
    return None


@click.command()
@click.argument("target", required=False)
@click.option("--stack", help="Stack axis (e.g. ros2-desktop, px4-sitl).")
@click.option("--distro", help="Distro axis (e.g. jazzy, humble).")
@click.option("--hardware", help="Hardware axis (cpu, gpu).")
@click.option("--all", "all_flag", is_flag=True, help="Render every configured target.")
@click.option("--write", is_flag=True, help="Write to output/<target>/Dockerfile.")
@click.option("--dry-run", is_flag=True, help="Print rendered Dockerfile to stdout.")
@click.option("--list", "list_flag", is_flag=True, help="List configured targets.")
@click.option(
    "--tags",
    "tags_flag",
    is_flag=True,
    help="Print '<output-name> <image-tag>' per target (for build.sh).",
)
def main(target, stack, distro, hardware, all_flag, write, dry_run, list_flag, tags_flag):
    """Compose Dockerfiles from (stack, distro, hardware) axes."""
    config = load_config()
    env = make_env()

    if list_flag:
        for s, d, h in all_targets(config):
            click.echo(target_name(s, d, h))
        return

    if tags_flag:
        for s, d, h in all_targets(config):
            click.echo(f"{target_name(s, d, h)} {image_tag(s, d, h)}")
        return

    # Resolve which triples to render.
    triples = []
    if all_flag:
        triples = list(all_targets(config))
    elif stack and distro and hardware:
        triples = [(stack, distro, hardware)]  # ad-hoc combo, need not be listed
    elif target:
        found = find_target_by_name(config, target)
        if not found:
            raise click.ClickException(
                f"no target named '{target}'. Run --list, or pass "
                f"--stack/--distro/--hardware for an ad-hoc combo."
            )
        triples = [found]
    else:
        raise click.UsageError(
            "provide a TARGET name, all of --stack/--distro/--hardware, "
            "--all, or --list."
        )

    if not write and not dry_run:
        dry_run = True

    for s, d, h in triples:
        name = target_name(s, d, h)
        text = render_target(config, env, s, d, h)
        if write:
            dest = write_output(name, text)
            click.echo(f"wrote {dest.relative_to(ROOT)}")
        if dry_run:
            if len(triples) > 1:
                click.echo(f"# ===== {name} =====")
            click.echo(text)


if __name__ == "__main__":
    main()
