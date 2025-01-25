# python-helpers
Scripts/Aliases for python, pyenv, virtualenvs, and jupyter.

I use this repo as a submodule of [runsascoded/.rc] (loaded [here][load]).

It can be installed standalone like:
```bash
. <(curl -L https://j.mp/_rc) ryan-williams/py-helpers
```

Then various helpers will be available, e.g.:

```bash
# Install pyenv, and required Python dependencies for the current OS
install_pyenv
# Same as above, but also installs the given Python version, and sets it as "global"
install_pyenv 3.12.7

# Install miniconda, and configure the libmamba solver
install_conda

# Misc
py 2+2  # 4
pex  # Print python executable path
```

[load]: https://github.com/runsascoded/.rc/blob/fe648a5f4a1f259593168f68f690c114a652d492/.rc#L114
[runsascoded/.rc]: https://github.com/runsascoded/.rc
