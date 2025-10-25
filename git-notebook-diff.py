#!/usr/bin/env -S uv run
# /// script
# dependencies = ["click"]
# ///

import subprocess
from functools import partial
from sys import stderr
from typing import Optional

import click
from click import argument, option

err = partial(print, file=stderr)


def run_cmd(*args, check=True):
    """Run a command and return stdout."""
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, args, result.stdout, result.stderr)
    return result.stdout.strip() if result.returncode == 0 else None


def get_nb_attr() -> Optional[str]:
    """Get the diff attribute type for notebooks."""
    attr = run_cmd('git', 'attr-diff-type', 'foo.ipynb', check=False)
    if attr:
        return attr

    err('No .gitattributes found for *.ipynb; try:')
    err('')
    attrs_file = run_cmd('git', 'config', 'core.attributesfile', check=False)
    if not attrs_file:
        err('    git config --global core.attributesfile ~/.gitattributes')
        attrs_file = '~/.gitattributes'
    else:
        attrs_file = f'~/{attrs_file}'
    err(f'    echo "*.ipynb diff=nb" >> {attrs_file}')
    return None


def get_config(key: str, is_global: bool = False) -> Optional[str]:
    """Get a git config value."""
    cmd_args = ['git', 'config']
    if is_global:
        cmd_args.append('--global')
    cmd_args.append(key)
    return run_cmd(*cmd_args, check=False)


def set_config(key: str, value: str, is_global: bool = False):
    """Set a git config value."""
    cmd_args = ['git', 'config']
    if is_global:
        cmd_args.append('--global')
    cmd_args.extend([key, value])
    err(' '.join(cmd_args))
    subprocess.run(cmd_args, check=True)


def unset_config(key: str, is_global: bool = False):
    """Unset a git config value."""
    cmd_args = ['git', 'config']
    if is_global:
        cmd_args.append('--global')
    cmd_args.extend(['--unset', key])
    err(' '.join(cmd_args))
    subprocess.run(cmd_args, check=False)


@click.group()
def main():
    """Git notebook diff configuration helper using nbdime."""
    pass


@main.command()
@option('-g', '--global', 'is_global', is_flag=True, help='Apply globally instead of locally')
def enable(is_global: bool):
    """Enable nbdime (restore saved config or default to -s)."""
    attr = get_nb_attr()
    if not attr:
        raise SystemExit(1)

    # Check if there's a saved config to restore
    saved = get_config(f'diff.{attr}.command-saved', is_global)
    if saved:
        set_config(f'diff.{attr}.command', saved, is_global)
    else:
        # Default to sources-only mode
        set_config(f'diff.{attr}.command', 'git-nbdiffdriver diff -s', is_global)


@main.command()
@option('-g', '--global', 'is_global', is_flag=True, help='Apply globally instead of locally')
def disable(is_global: bool):
    """Disable nbdime (save current config before unsetting)."""
    attr = get_nb_attr()
    if not attr:
        raise SystemExit(1)

    # Save current config if it exists
    current = get_config(f'diff.{attr}.command', is_global)
    if current:
        set_config(f'diff.{attr}.command-saved', current, is_global)
        unset_config(f'diff.{attr}.command', is_global)
    else:
        err('nbdime already disabled')


@main.command()
@option('-g', '--global', 'is_global', is_flag=True, help='Apply globally instead of locally')
def toggle(is_global: bool):
    """Toggle nbdime on/off."""
    attr = get_nb_attr()
    if not attr:
        raise SystemExit(1)

    # Check if currently enabled
    current = get_config(f'diff.{attr}.command', is_global)
    if current:
        # Currently enabled, disable it
        ctx = click.Context(disable)
        ctx.invoke(disable, is_global=is_global)
    else:
        # Currently disabled, enable it
        ctx = click.Context(enable)
        ctx.invoke(enable, is_global=is_global)


@main.command()
@option('-g', '--global', 'is_global', is_flag=True, help='Apply globally instead of locally')
@argument('flag_args', required=False)
def flags(is_global: bool, flag_args: Optional[str] = None):
    """Set or show nbdime flags.

    Examples:
        git-notebook-diff.py flags -s    # sources-only
        git-notebook-diff.py flags       # show current
        git-notebook-diff.py flags ""    # unfiltered
    """
    attr = get_nb_attr()
    if not attr:
        raise SystemExit(1)

    if flag_args is None:
        # Print current config
        current = get_config(f'diff.{attr}.command', is_global)
        if current:
            print(current)
        else:
            err('nbdime not configured')
    else:
        # Set flags
        if flag_args:
            cmd_value = f'git-nbdiffdriver diff {flag_args}'
        else:
            cmd_value = 'git-nbdiffdriver diff'
        set_config(f'diff.{attr}.command', cmd_value, is_global)


if __name__ == '__main__':
    main()
