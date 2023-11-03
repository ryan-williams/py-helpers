#!/usr/bin/env python
import json
from io import StringIO

import click
import pandas as pd
from utz import singleton


@click.command()
@click.option('-c', '--cell-idx', type=int, required=True)
@click.argument('nb_path')
def main(cell_idx, nb_path):
    with open(nb_path, 'r') as f:
        nb = json.load(f)
    cells = nb['cells']
    cell = cells[cell_idx]
    outputs = cell['outputs']
    output = singleton(outputs, dedupe=False)
    data = output['data']
    html_rows = data['text/html']
    html = '\n'.join(html_rows)
    tbls = pd.read_html(StringIO(html))
    for tbl in tbls:
        print(tbl)


if __name__ == '__main__':
    main()
