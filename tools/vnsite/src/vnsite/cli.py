"""Command-line interface for per-site Docker Compose deployments."""

import os
import shutil
import subprocess
from importlib.resources import files
from pathlib import Path

import click


TEMPLATES = files("vnsite") / "data"


def _site_path(path: str) -> Path:
    return Path(path).expanduser().resolve()


def _run_compose(path: str, arguments: tuple[str, ...]) -> None:
    site_path = _site_path(path)
    if not site_path.is_dir():
        raise click.ClickException(f"Site directory does not exist: {site_path}")
    try:
        subprocess.run(["docker", "compose", *arguments], cwd=site_path, check=True)
    except FileNotFoundError as error:
        raise click.ClickException("Docker was not found on PATH") from error
    except subprocess.CalledProcessError as error:
        raise click.exceptions.Exit(error.returncode) from error


def _copy_template(name: str, destination: Path) -> None:
    if destination.exists():
        return
    with (TEMPLATES / name).open("rb") as source, destination.open("wb") as target:
        shutil.copyfileobj(source, target)


@click.group()
def main() -> None:
    """Create and manage Client_API_VN site deployments."""


@main.command()
@click.argument("path", default=".", type=click.Path(file_okay=False, path_type=str))
def create(path: str) -> None:
    """Create a site deployment in PATH."""
    site_path = _site_path(path)
    site_path.mkdir(parents=True, exist_ok=True)
    site_name = site_path.name
    if not site_name or not all(character.isalnum() or character in "_.-" for character in site_name):
        raise click.ClickException(f"Invalid site directory name: {site_name!r}")

    _copy_template("docker-compose.yml", site_path / "docker-compose.yml")
    env_path = site_path / ".env"
    if not env_path.exists():
        _copy_template("env.example", env_path)
        env_path.write_text(
            env_path.read_text(encoding="utf-8").replace("SITE=faune79", f"SITE={site_name}"),
            encoding="utf-8",
        )

    for directory in (site_path / "data", site_path / "logs", site_path / "config"):
        directory.mkdir(exist_ok=True)
        if os.name != "nt":
            directory.chmod(0o700)
    click.echo(f"Created {site_path}. Edit {env_path}, then run: vnsite start {site_path}")


@main.command()
@click.argument("path", default=".", type=click.Path(file_okay=False, path_type=str))
def start(path: str) -> None:
    """Start the site containers."""
    _run_compose(path, ("up", "-d"))


@main.command()
@click.argument("path", default=".", type=click.Path(file_okay=False, path_type=str))
def stop(path: str) -> None:
    """Stop and remove the site containers."""
    _run_compose(path, ("down",))


@main.command()
@click.argument("path", default=".", type=click.Path(file_okay=False, path_type=str))
def restart(path: str) -> None:
    """Restart the site containers."""
    _run_compose(path, ("restart",))


@main.command()
@click.argument("path", default=".", type=click.Path(file_okay=False, path_type=str))
def logs(path: str) -> None:
    """Follow the site container logs."""
    _run_compose(path, ("logs", "-f"))


if __name__ == "__main__":
    main()