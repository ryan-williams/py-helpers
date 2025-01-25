# Set this to run on Python REPL startup:
#
# export PYTHONSTARTUP=$HOME/.rc/py/startup.py

try:
    from utz import *
    err("Imported utz")
except ImportError:
    import sys
    sys.stderr.write("utz not found\n")
