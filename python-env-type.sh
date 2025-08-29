#!/usr/bin/env bash

# Python environment type declaration system
# Allows projects to declare their preferred environment type (uv/venv/conda)
#
# Usage:
#   1. Create a .python-env file with one of: uv, venv, conda, conda:env_name
#   2. Or let it auto-detect from existing files (uv.lock, environment.yml, etc.)
#   3. Use py_activate to activate the appropriate environment
#
# Examples:
#   echo "uv" > .python-env         # Use uv managed venv
#   echo "venv" > .python-env       # Use standard venv
#   echo "conda:myproject" > .python-env  # Use specific conda env

# Get the Python environment type for current directory
get_python_env_type() {
    # Check explicit declaration first
    if [[ -f .python-env ]]; then
        cat .python-env | head -1 | tr -d '\n'
        return 0
    fi

    # Auto-detect based on files present
    if [[ -f environment.yml ]] || [[ -f conda.yaml ]]; then
        echo "conda"
    elif [[ -f uv.lock ]]; then
        echo "uv"
    elif [[ -f requirements.txt ]] || [[ -f pyproject.toml ]] || [[ -f setup.py ]]; then
        echo "venv"
    else
        echo "venv"  # Default
    fi
}

# Activate the appropriate Python environment based on type
py_activate() {
    local env_type=$(get_python_env_type)

    case "$env_type" in
        conda:*)
            # Format: conda:env_name
            local env_name="${env_type#conda:}"
            if command -v conda &>/dev/null; then
                echo "Activating conda environment: $env_name" >&2
                conda activate "$env_name"
            else
                echo "Error: conda not found. Please install Anaconda/Miniconda." >&2
                return 1
            fi
            ;;
        conda)
            # Look for env name in environment.yml
            if [[ -f environment.yml ]]; then
                local env_name=$(grep "^name:" environment.yml | awk '{print $2}')
                if [[ -n "$env_name" ]]; then
                    echo "Activating conda environment: $env_name" >&2
                    conda activate "$env_name"
                else
                    echo "Error: No environment name found in environment.yml" >&2
                    return 1
                fi
            elif [[ -f conda.yaml ]]; then
                local env_name=$(grep "^name:" conda.yaml | awk '{print $2}')
                if [[ -n "$env_name" ]]; then
                    echo "Activating conda environment: $env_name" >&2
                    conda activate "$env_name"
                else
                    echo "Error: No environment name found in conda.yaml" >&2
                    return 1
                fi
            else
                echo "Error: Conda environment specified but no environment.yml or conda.yaml found" >&2
                return 1
            fi
            ;;
        uv|venv)
            # Use venv with PATH (same handling for both)
            if [[ -d .venv/bin ]]; then
                export PATH="$(pwd)/.venv/bin:$PATH"
                echo "Added .venv/bin to PATH ($(get_python_env_type) mode)" >&2
                python --version >&2
            elif [[ ! -d .venv ]]; then
                echo "No .venv found, creating with default Python..." >&2
                # Source venv-helpers if available
                if [[ -f "$HOME/.rc/py/venv-helpers.sh" ]]; then
                    source "$HOME/.rc/py/venv-helpers.sh"
                    venv_create
                    export PATH="$(pwd)/.venv/bin:$PATH"
                else
                    # Fallback to basic venv creation
                    if command -v uv &>/dev/null && [[ "$env_type" == "uv" ]]; then
                        uv venv .venv
                    else
                        python -m venv .venv
                    fi
                    export PATH="$(pwd)/.venv/bin:$PATH"
                fi
            fi
            ;;
        *)
            echo "Unknown environment type: $env_type" >&2
            return 1
            ;;
    esac
}

# Set Python environment type for current directory
set_python_env_type() {
    local env_type="${1:-}"

    if [[ -z "$env_type" ]]; then
        echo "Usage: set_python_env_type <type>" >&2
        echo "  Types: uv, venv, conda, conda:env_name" >&2
        return 1
    fi

    # Validate type
    case "$env_type" in
        uv|venv|conda|conda:*)
            echo "$env_type" > .python-env
            echo "Set Python environment type to: $env_type" >&2
            ;;
        *)
            echo "Invalid type: $env_type" >&2
            echo "Valid types: uv, venv, conda, conda:env_name" >&2
            return 1
            ;;
    esac
}

# Show current Python environment info
py_env_info() {
    local env_type=$(get_python_env_type)
    echo "Python environment type: $env_type" >&2

    case "$env_type" in
        conda*)
            if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
                echo "Active conda env: $CONDA_DEFAULT_ENV" >&2
            else
                echo "No conda env active" >&2
            fi
            ;;
        uv|venv)
            if [[ -d .venv ]]; then
                if [[ -f .venv/current ]]; then
                    echo "Current venv version: $(cat .venv/current)" >&2
                fi
                echo "Python: $(which python)" >&2
                python --version >&2
            else
                echo "No .venv directory found" >&2
            fi
            ;;
    esac
}

# Aliases for convenience
alias pya=py_activate
alias pyei=py_env_info
alias pyet=set_python_env_type

# Export functions for use in other scripts
export -f get_python_env_type
export -f py_activate
export -f set_python_env_type
export -f py_env_info