#!/usr/bin/env bash

# Python direnv runtime config - sourced by .envrc files
# Handles both uv projects and multi-version venv projects
# Usage in .envrc: source $HOME/.rc/py/py-direnv-rc.sh && py_direnv_rc

# Don't source venv-helpers in direnv context (causes defn errors)
# Just define the minimal functions we need


# pyenv deactivation removed - no longer using pyenv

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

# Main runtime function called by .envrc files
py_direnv_rc() {
    # Check if this is a uv.lock project
    if [ -f "uv.lock" ]; then
        # UV project with lock file
        echo "Detected uv.lock project" >&2

        # Create venv if it doesn't exist
        if [ ! -d .venv ]; then
            echo "Creating uv virtual environment..." >&2
            uv sync --frozen || uv venv
        fi

        # Set UV_PROJECT_ENVIRONMENT for new structure
        if [[ -L ".venv/cur" ]]; then
            export UV_PROJECT_ENVIRONMENT=".venv/cur"
        elif [[ -L ".venv" ]]; then
            export UV_PROJECT_ENVIRONMENT="$(readlink .venv)"
        fi

        # Activate the venv
        source .venv/bin/activate

        # Create pip shim if needed
        create_uv_pip_shim

        # Ensure .venv/bin is at the front of PATH (override any remaining python)
        export PATH="$PWD/.venv/bin:$PATH"

    else
        # For all other projects - use multi-version venv support
        # This handles both uv projects without lock files and regular venv projects
        py_direnv_activate
    fi

    # Optional: Set Python startup file if configured
    if [ -z "$PYTHONSTARTUP" ] && [ -f "$HOME/.rc/py/startup.py" ]; then
        export PYTHONSTARTUP="$HOME/.rc/py/startup.py"
    fi
}

# Multi-version activation function (for non-uv projects)
py_direnv_activate() {
    # Simply activate .venv if it exists (new structure)
    if [[ -f ".venv/bin/activate" ]]; then
        source .venv/bin/activate

        # For new structure, set UV_PROJECT_ENVIRONMENT to the actual venv directory
        # This prevents uv sync from overwriting our symlink structure
        if [[ -f ".venv/current" ]]; then
            # Read the current version from the marker file
            local current_version=$(cat .venv/current)
            export UV_PROJECT_ENVIRONMENT=".venv/${current_version}"
        elif [[ -L ".venv/bin" ]]; then
            # Follow the symlink to get the actual venv directory
            local bin_target=$(readlink .venv/bin)
            local venv_dir="${bin_target%/bin}"  # Remove /bin suffix
            export UV_PROJECT_ENVIRONMENT=".venv/${venv_dir}"
        else
            # Fallback to .venv if structure is unclear
            export UV_PROJECT_ENVIRONMENT=".venv"
        fi

        echo "Activated $(python --version 2>&1)"
    elif [[ ! -e ".venv" ]]; then
        echo "Warning: No Python venv found. Run 'spd' to set up project." >&2
    else
        echo "Warning: .venv exists but no activate script found" >&2
    fi
}

# Export functions so they're available when sourced
export -f py_direnv_rc 2>/dev/null || true
export -f py_direnv_activate 2>/dev/null || true
export -f create_uv_pip_shim 2>/dev/null || true
export -f find_venv 2>/dev/null || true
