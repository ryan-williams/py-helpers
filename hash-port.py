#!/usr/bin/env python
from hashlib import sha256
from os import getcwd
from os.path import basename

import click


@click.command()
@click.option('-r', '--range', 'port_range', default=f'{2**10}:{2**16}', help='Half-open range of ports to map <name> into')
@click.argument('name', required=False)
def main(port_range, name):
    """Map a string to a port number, by hashing it."""
    start, end = map(int, port_range.split(':'))
    name = name or basename(getcwd())
    digest = sha256(name.encode('utf-8')).hexdigest()
    port = start + int(digest, 16) % (end - start)
    print(port)


if __name__ == '__main__':
    main()
