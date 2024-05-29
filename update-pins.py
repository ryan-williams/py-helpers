#!/usr/bin/env python
import importlib.metadata
import re
from functools import partial
from sys import stderr, stdout

import click
from pip._internal.network.session import PipSession
from pip._internal.req import parse_requirements

REQ_RGX = re.compile(r'(?P<name>[a-zA-Z0-9\-_.]+)(?:\[(?P<extra>[a-zA-Z0-9\-_]+)])?(?:(?P<op>[=><!~]+)(?P<version>[a-zA-Z0-9\-_.]+))?')


err = partial(print, file=stderr)


@click.command()
@click.option('-i', '--in-place', is_flag=True, help='Update the requirements file in place')
@click.option('-o', '--output-path', help='Output path for the updated requirements file; "-" for stdout')
@click.argument('requirements_path', default='requirements.txt')
def main(in_place, output_path, requirements_path):
    """Update pinned dependencies in a requirements file to match the currently installed versions.

    Expects a couple steps to take place before-hand:
    1. Remove version constraints from the requirements file
    2. Make a new virtualenv and perform a `pip install -r`, to pick up a recent, mutually-compatible set of dependency versions

    Then this script will populate the requirements file with the currently installed versions.
    """
    installed_packages = importlib.metadata.distributions()
    deps = {
        package.metadata['Name'].lower(): package.version
        for package in installed_packages
    }

    session = PipSession()
    parsed_requirements = list(parse_requirements(requirements_path, session=session))

    if in_place:
        if output_path:
            raise ValueError("Cannot specify both --in-place and --output-path")
        else:
            output_path = requirements_path

    if not output_path or output_path == '-':
        out_fd = stdout
        close = False
    else:
        out_fd = open(output_path, 'w')
        close = True

    out = partial(print, file=out_fd)

    for req in parsed_requirements:
        dep = req.requirement
        m = REQ_RGX.match(dep)
        if m:
            name = m.group('name').lower()
            if name in deps:
                version = deps[name]
                extra = m.group('extra')
                if extra:
                    out(f"{name}[{extra}]=={version}")
                else:
                    out(f"{name}=={version}")
            else:
                err(f"Name {name} not found in deps")
                out(dep)
        else:
            err(f"Could not parse requirement {dep}")
            out(dep)

    if close:
        out_fd.close()


if __name__ == '__main__':
    main()
