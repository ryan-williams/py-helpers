#!/usr/bin/env python

try:
    import utz
except ImportError:
    from subprocess import check_call
    from sys import executable
    check_call([executable,'-m','pip','install','-u','utz'])

from utz import *


parser = ArgumentParser()
parser.add_argument('-i','--image',default='runsascoded/py3.8',help='Base docker image to build on')
parser.add_argument('-P','--port',default=8899,help='Port to run Jupyter on inside the container, and also to expose on the host')
parser.add_argument('-a','--apts',help='Comma-separated list of packages to apt-get install')
parser.add_argument('-p','--pips',help='Comma-separated list of packages to pip install')
parser.add_argument('-n','--name',help='Container name (defaults to directory basename)')
parser.add_argument('-R','--skip-requirements-txt',action='store_true',help="Skip reading + pip-install any requirements.txt that is present")
parser.add_argument('-s','--shell',action='store_true',help="Open a /bin/bash shell in the container (instead of running a jupyter server)")
args = parser.parse_args()
image = args.image
port = args.port
apts = args.apts.split(',') if args.apts else []
pips = args.pips.split(',') if args.apts else []
name = args.name
skip_requirements_txt = args.skip_requirements_txt
shell = args.shell


pwd = getcwd()


# Path inside Docker container to mount current directory/repo
dst = "/src"


with TemporaryDirectory() as dir:
    dockerfile = join(pwd, 'Dockerfile')
    tmp_dockerfile = join(dir, 'Dockerfile')
    if exists(dockerfile):
        docker = True
        copy(dockerfile, tmp_dockerfile)

    if apts:
        docker = True
        with open(tmp_dockerfile, 'a') as f:
            f.write(f'RUN apt-get update && apt-get install {" ".join(apts)}\n')

    pips = []
    reqs_txt = join(pwd, 'requirements.txt')
    if exists(reqs_txt) and not skip_requirements_txt:
        with open(reqs_txt, 'r') as f:
            pips += [ line.rstrip('\n') for line in f.readlines() if line ]

    if pips:
        docker = True
        with open(tmp_dockerfile, 'a') as f:
            f.write(f'RUN pip install {" ".join(pips)}\n')

    if docker:
        run('docker','build','-t',image,'-f',tmp_dockerfile,dir)


uid = line('id','-u')
gid = line('id','-g')

if check('docker','container','inspect',name):
    run('docker','container','rm',name)

user = o({
    'name': line('git','config','user.name'),
    'email': line('git','config','user.email'),
})

if shell:
    flags = [ '--entrypoint', '/bin/bash' ]
    args = []
else:
    flags = []
    args = [ f'{port}' ]

envs = {
   'HOME': '/home',
   'GIT_AUTHOR_NAME'    : user.name,
   'GIT_AUTHOR_EMAIL'   : user.email,
   'GIT_COMMITTER_NAME' : user.name,
   'GIT_COMMITTER_EMAIL': user.email,
}

run(
    [
        'docker','run',
        '-v',f'{pwd}:{dst}',
        '-w',dst,
        '-p',f'{port}:{port}',
        '-u',f'{uid}:{gid}',
        '--name',name,
    ] + [
        arg for
        k,v in envs.items()
        for arg in [k,v]
    ] + \
    flags + \
    [ image ] + \
    args
)
