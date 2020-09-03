#!/usr/bin/env python
#
# Open the token-authenticated URL toa running notebook server in the browser.
#
# - If unable to (because the `open` command is not found), attempt to copy the URL to the clipboard (using `pbcopy`).
# - If `pbcopy` isn't found, print the authenticated URL to stdout.
# - If more than one server is found, print all authenticated URLs (one per line)

import json
from subprocess import CalledProcessError, check_call, check_output, Popen, PIPE, DEVNULL


def cmd_exists(cmd):
    try:
        check_call(['which',cmd], stdout=DEVNULL, stderr=DEVNULL)
        return True
    except CalledProcessError:
        return False


def try_copy(url):
    if cmd_exists('pbcopy'):
        p = Popen(['pbcopy'], stdout=PIPE, stdin=PIPE, stderr=PIPE)
        p.communicate(input=url)
        return True
    else:
        return False


def try_open(url):
    if cmd_exists('open'):
        check_call(['open',url])
        return True
    else:
        return False


def get_url(notebook):
    return '%s?token=%s' % (notebook['url'], notebook['token'])


notebooks = json.loads(check_output(['jupyter','notebook','list','--jsonlist']).decode())
if len(notebooks) == 1:
    [notebook] = notebooks
    url = get_url(notebook)
    if not try_open(url) and not try_copy(url):
        print(url)
elif not notebooks:
    print('No running notebook servers found')
else:
    print('\n'.join([ get_url(notebook) for notebook in notebooks ]))
