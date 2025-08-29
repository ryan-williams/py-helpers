# python helpers
Scripts/Aliases for python, [pyenv], virtualenvs, and Jupyter.

I use this repo as a submodule of [runsascoded/.rc] (loaded [here][load]). It's also mirrored [on GitLab][gl].

It can be installed standalone like:
```bash
. <(curl -L https://j.mp/_rc) ryan-williams/py-helpers
```

[j.mp/_rc] is a bit.ly redirect to [clone-and-source.sh]; the above clones this repo and `source`s the `.*rc` files ([.conda-rc], [.jupyter-rc], [.py-rc]).

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
pci os path  # check import: verify `from os import path` works
```

## Python Virtual Environment Management

All venvs use versioned naming (`.venv3.12.7`) with `.venv` as a symlink for compatibility.

### Quick Start

#### Option 1: Simple PATH-based (Recommended)

Add to your `.bashrc` or `.zshrc`:
```bash
source $HOME/.rc/py/venv-path-init.sh
```

Then just create venvs and they'll be used automatically:
```bash
vc 3.12                # Create Python 3.12 venv
vsw 3.12               # Switch to it (creates .venv symlink)
# Now .venv/bin is automatically in PATH when you're in this directory
```

#### Option 2: With direnv

```bash
spd                    # Setup with current Python version
spd 3.12               # Setup with Python 3.12
spd 3.11 3.12 3.13     # Setup with multiple versions
```

#### Option 3: Manual activation

```bash
va                     # Activate .venv (create if needed)
va 3.12                # Activate Python 3.12 (create if needed)
```

### Core Commands

| Command | Purpose | Creates `.envrc`? |
|---------|---------|-------------------|
| `spd [versions...]` | Setup project with direnv | Yes |
| `va [version]` | Activate venv | No |
| `vsw version` | Switch Python version | No |
| `vl` | List available venvs | No |
| `vvi versions...` | Create multiple venvs | No |

### Version Switching

To switch Python versions, change the symlink:
```bash
vsw 3.12   # Changes .venv symlink to Python 3.12
```

If using direnv, it will auto-activate the new version when you re-enter the directory.

See [`example.dockerfile`] for an example installing and using in an Ubuntu image.

[pyenv]: https://github.com/pyenv/pyenv
[runsascoded/.rc]: https://github.com/runsascoded/.rc
[load]: https://github.com/runsascoded/.rc/blob/fe648a5f4a1f259593168f68f690c114a652d492/.rc#L114
[gl]: https://gitlab.com/runsascoded/rc/py
[`example.dockerfile`]: example.dockerfile

[j.mp/_rc]: https://j.mp/_rc
[clone-and-source.sh]: https://github.com/ryan-williams/git-helpers/blob/main/clone/clone-and-source.sh
[.conda-rc]: .conda-rc
[.jupyter-rc]: .jupyter-rc
[.py-rc]: .py-rc
