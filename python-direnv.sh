#!/usr/bin/env bash

# Smart Python environment detection and activation for direnv
# Source this from .envrc files to auto-detect and activate Python environments

# Function to create pip shim for uv
create_uv_pip_shim() {
    if [ -f .venv/bin/python ] && ! [ -f .venv/bin/pip ]; then
        cat > .venv/bin/pip <<'EOF'
#!/bin/bash
exec uv pip "$@"
EOF
        chmod +x .venv/bin/pip
    fi
}

# Main function to set up Python environment based on project type
setup_python_direnv() {
    # Detect and activate appropriate Python environment
    if [ -f "uv.lock" ] || ([ -f "pyproject.toml" ] && grep -q "uv" pyproject.toml 2>/dev/null); then
        # UV project
        echo "Detected uv project" >&2

        # Create venv if it doesn't exist
        if [ ! -d .venv ]; then
            echo "Creating uv virtual environment..." >&2
            uv sync --no-dev || uv venv
        fi

        # Activate the venv
        source .venv/bin/activate

        # Create pip shim if needed
        create_uv_pip_shim

        # Ensure .venv/bin is at the front of PATH (override pyenv)
        export PATH="$PWD/.venv/bin:$PATH"

    elif [ -f "environment.yml" ] || [ -f "environment.yaml" ] || [ -f "conda-env.yml" ]; then
        # Conda/Mamba project
        echo "Detected conda project" >&2

        # Set up conda if not already active
        if [ -z "$CONDA_DEFAULT_ENV" ]; then
            if [ -n "$CONDA_ROOT" ]; then
                __conda_setup="$("$CONDA_ROOT/base/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
                if [ $? -eq 0 ]; then
                    eval "$__conda_setup"
                fi
            elif [ -n "$CONDA_PREFIX" ]; then
                conda_sh="$CONDA_PREFIX/etc/profile.d/conda.sh"
                if [ -f "$conda_sh" ]; then
                    . "$conda_sh"
                fi
            fi
        fi

        # Activate environment based on directory name or explicit env name
        if [ -f ".conda-env-name" ]; then
            conda activate "$(cat .conda-env-name)"
        else
            # Try to activate env with same name as directory
            dir_name="$(basename "$PWD")"
            if conda info --envs | grep -q "^$dir_name "; then
                conda activate "$dir_name"
            fi
        fi

    elif [ -f ".python-version" ] && which pyenv &>/dev/null; then
        # Pyenv project
        echo "Detected pyenv project" >&2

        # pyenv should handle this automatically, but ensure it's activated
        eval "$(pyenv init --path)"
        eval "$(pyenv virtualenv-init -)"

    elif [ -d "venv" ]; then
        # Standard venv
        echo "Detected standard venv" >&2
        source venv/bin/activate

    elif [ -d ".venv" ] && [ -f ".venv/bin/activate" ]; then
        # Standard .venv (could be from poetry, pipenv, or manual creation)
        echo "Detected .venv" >&2
        source .venv/bin/activate

        # If this is actually a uv-managed project without uv.lock, create pip shim
        if which uv &>/dev/null && [ -f "pyproject.toml" ]; then
            create_uv_pip_shim
            export PATH="$PWD/.venv/bin:$PATH"
        fi
    fi

    # Optional: Set Python startup file if configured
    if [ -z "$PYTHONSTARTUP" ] && [ -f "$HOME/.rc/py/startup.py" ]; then
        export PYTHONSTARTUP="$HOME/.rc/py/startup.py"
    fi

    # Show which Python/pip we're using (helpful for debugging)
    # Note: direnv captures stdout for environment changes, so use stderr for messages
    echo "Python: $(which python)" >&2
    echo "Pip: $(which pip 2>/dev/null || echo 'pip not found')" >&2
}

# Export the function so it's available when sourced
export -f setup_python_direnv
export -f create_uv_pip_shim