#!/usr/bin/env python
from os import cpu_count

import json

import click
from utz import process, err


@click.command()
@click.option('-a', '--after-specs', is_flag=True)
@click.option('-b', '--before-specs', is_flag=True)
@click.option('-c', '--compact-json', is_flag=True)
@click.option('-d', '--diff-specs', is_flag=True)
@click.option('-p', '--parallel', is_flag=True, help="Parallelize `docker run`s with `joblib`")
@click.option('-s', '--short', count=True)
@click.option('-v', '--verbose', is_flag=True)
@click.argument('before_img')
@click.argument('after_img')
def main(after_specs, before_specs, compact_json, diff_specs, parallel, short, verbose, before_img, after_img):
    if sum(1 if spec_fmt else 0 for spec_fmt in [ after_specs, before_specs, diff_specs ]) > 1:
        raise ValueError("Pass at most one of {-a/--after-specs,-b/--before-specs,-d/--diff-specs}")

    def docker_conda_list(img):
        kwargs = {} if verbose else { 'log': lambda _: None }
        deps = process.json('docker', 'run', '--rm', '--entrypoint', 'conda', img, 'list', '--json', **kwargs)
        if short:
            return [
                {
                    k: v
                    for k, v in dep.items()
                    if k in { 'name', 'version', 'build_string', 'channel' }
                }
                for dep in deps
            ]
        else:
            return deps

    before_deps = after_deps = None
    if parallel:
        try:
            from joblib import Parallel, delayed
            parallel = Parallel(cpu_count())
            fn = delayed(docker_conda_list)
            before_deps, after_deps = parallel(fn(img) for img in [ before_img, after_img ])
        except ImportError:
            pass
    if before_deps is None:
        before_deps = docker_conda_list(before_img)
        after_deps = docker_conda_list(after_img)
    after_deps_map = { dep['name']: dep for dep in after_deps }

    diffs = []
    for before_dep in before_deps:
        name = before_dep['name']
        if name in after_deps_map:
            after_dep = after_deps_map[name]
            if before_dep != after_dep:
                diffs.append(dict(
                    name=name,
                    before=before_dep,
                    after=after_dep,
                ))

    def build_string(dep):
        spec = f'{dep["name"]}=={dep["version"]}'
        if short == 2:
            return spec
        elif short == 1:
            return f'{spec} ({dep["channel"]})'
        elif short == 0:
            return f'{spec}[{dep["build_string"]}]'
        else:
            raise ValueError(f'-s/--short should be 0, 1, or 2')

    if diff_specs:
        for diff in diffs:
            before = diff['before']
            after = diff['after']
            before_str = build_string(before)
            after_str = build_string(after)
            if before_str == after_str:
                err(f"{before_str} == {after_str}: {before}, {after}")
            print(f'-{before_str}')
            print(f'+{after_str}')
    elif before_specs:
        print(" ".join(build_string(diff['before']) for diff in diffs))
    elif after_specs:
        print(" ".join(build_string(diff['after']) for diff in diffs))
    else:
        json_kwargs = {} if compact_json else { 'indent': 2 }
        print(json.dumps(diffs, **json_kwargs))


if __name__ == '__main__':
    main()
