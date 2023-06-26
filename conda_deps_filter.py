#!/usr/bin/env python
import json

import click
from utz import process, singleton


@click.command()
@click.option('-h', '--histogram', count=True, help="1x: print number of occurrences of each matching dep constraint, sorted by constraint string; 2x: sorted by occurrence count (increasing); 3x: sorted by occurrence count (decreasing)")
@click.option('-f', '--dep-filter', 'dep_filters', multiple=True, help="One or more filters to apply to the `depends` array of each returned build")
@click.option('-v', '--verbose', is_flag=True, help="Debug-print `conda search --json` commands before executing")
@click.argument('specs', nargs=-1)
def main(histogram, dep_filters, verbose, specs):
    dep_map = {}
    for spec in specs:
        kwargs = {} if verbose else { 'log': lambda _: None }
        rv = process.json('conda', 'search', '--json', spec, **kwargs)
        _, builds = singleton(rv, dedupe=False)
        for build in builds:
            name = f"{build['name']}=={build['version']}[{build['build']}]"
            deps = [
                dep
                for dep in build['depends']
                if any(
                    dep_filter in dep
                    for dep_filter in dep_filters
                )
            ]
            if len(dep_filters) == 1:
                dep_map[name] = deps[0] if deps else None
            else:
                dep_map[name] = deps

    if histogram:
        hist = {}
        for dep in dep_map.values():
            if dep not in hist:
                hist[dep] = 0
            hist[dep] += 1
        if histogram == 1:
            hist = dict(sorted(hist.items(), key=lambda k: k[0]))
        elif histogram == 2:
            hist = dict(sorted(hist.items(), key=lambda k: k[1]))
        elif histogram == 3:
            hist = dict(reversed(sorted(hist.items(), key=lambda k: k[1])))
        else:
            raise ValueError(f"-h/--histogram should be 0, 1, 2, or 3")

        print(json.dumps(hist, indent=2))
    else:
        print(json.dumps(dep_map, indent=2))


if __name__ == '__main__':
    main()
