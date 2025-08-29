#!/usr/bin/env bash

# New venv structure design to avoid nested symlink issues
#
# Structure:
#   .venv/
#     3.11.13/        # Full venv created by uv
#     3.12.11/        # Another version
#     bin -> 3.12.11/bin   # Direct symlink to current version's bin
#     lib -> 3.12.11/lib   # Direct symlink to current version's lib
#     include -> 3.12.11/include
#     pyvenv.cfg -> 3.12.11/pyvenv.cfg
#     current         # Text file containing current version (for scripts to read)
#
# This avoids the nested symlink issue where .venv/bin -> cur/bin -> 3.12.11/bin

# Create a venv with new structure
venv_create_new() {
    local py_spec="${1:-3.13}"
    local full_version=$(get_python_full_version "$py_spec")

    mkdir -p .venv
    local venv_path=".venv/${full_version}"

    if [[ -d "$venv_path" ]]; then
        echo "Venv $venv_path already exists" >&2
        venv_switch "$full_version"
        return 0
    fi

    echo "Creating $venv_path with Python $py_spec..." >&2
    if command -v uv &>/dev/null; then
        uv venv "$venv_path" --python "$py_spec"
        # Create pip wrapper for UV
        if [[ ! -f "$venv_path/bin/pip" ]]; then
            create_uv_pip_wrapper "$venv_path"
        fi
    else
        python${py_spec} -m venv "$venv_path"
    fi

    # Set this version as current
    venv_switch "$full_version"

    # Install dependencies if present
    venv_install_deps "$venv_path"
}

# Switch to a different Python version
venv_switch() {
    local version="$1"

    # Allow partial version matching
    local full_version=""
    if [[ -d ".venv/$version" ]]; then
        full_version="$version"
    else
        # Find matching version
        for dir in .venv/*/; do
            if [[ -d "$dir" ]]; then
                local v=$(basename "$dir")
                if [[ "$v" == "$version"* ]]; then
                    full_version="$v"
                    break
                fi
            fi
        done
    fi

    if [[ -z "$full_version" ]]; then
        echo "Version $version not found. Available versions:" >&2
        ls -d .venv/*/ 2>/dev/null | xargs -n1 basename | grep -E '^[0-9]' | sed 's/^/  /' >&2
        return 1
    fi

    # Update symlinks to point directly to the versioned directories
    ln -sfn "${full_version}/bin" .venv/bin
    ln -sfn "${full_version}/lib" .venv/lib
    ln -sfn "${full_version}/include" .venv/include
    ln -sfn "${full_version}/pyvenv.cfg" .venv/pyvenv.cfg

    # Store current version in a file for scripts
    echo "$full_version" > .venv/current

    echo "Switched to Python $full_version" >&2

    # If UV_PROJECT_ENVIRONMENT is set to .venv/cur, update it
    if [[ "$UV_PROJECT_ENVIRONMENT" == ".venv/cur" ]]; then
        export UV_PROJECT_ENVIRONMENT=".venv"
    fi
}

# Helper to create UV pip wrapper
create_uv_pip_wrapper() {
    local venv_path="$1"
    cat > "$venv_path/bin/pip" <<'EOF'
#!/bin/bash
# Wrapper for uv pip to handle common pip commands
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$(dirname "$SCRIPT_DIR")"

if [[ "$1" == "--version" ]] || [[ "$1" == "-V" ]]; then
    echo "pip (uv wrapper)"
    uv --version
else
    if [[ -n "$1" ]]; then
        COMMAND="$1"
        shift
        exec uv pip "$COMMAND" --python "$VENV_DIR/bin/python" "$@"
    else
        exec uv pip "$@"
    fi
fi
EOF
    chmod +x "$venv_path/bin/pip"
}

# Install dependencies if project files exist
venv_install_deps() {
    local venv_path="$1"

    if [[ -f "uv.lock" ]] && command -v uv &>/dev/null; then
        echo "UV project detected, run 'uv sync' to install dependencies" >&2
    elif [[ -f "pyproject.toml" ]] && command -v uv &>/dev/null; then
        echo "Installing dependencies with uv..." >&2
        uv pip install -e . --python "$venv_path/bin/python"
    elif [[ -f "pyproject.toml" ]] && [[ -f "$venv_path/bin/pip" ]]; then
        echo "Installing dependencies with pip..." >&2
        "$venv_path/bin/pip" install -e .
    elif [[ -f "requirements.txt" ]]; then
        echo "Installing requirements..." >&2
        if command -v uv &>/dev/null; then
            uv pip install -r requirements.txt --python "$venv_path/bin/python"
        else
            "$venv_path/bin/pip" install -r requirements.txt
        fi
    fi
}

# List available venv versions
venv_list_new() {
    if [[ ! -d .venv ]]; then
        echo "No .venv directory found" >&2
        return 1
    fi

    local current=""
    if [[ -f .venv/current ]]; then
        current=$(cat .venv/current)
    fi

    echo "Available Python versions in .venv:" >&2
    for dir in .venv/*/; do
        if [[ -d "$dir" ]]; then
            local v=$(basename "$dir")
            if [[ "$v" =~ ^[0-9] ]]; then
                if [[ "$v" == "$current" ]]; then
                    echo "  * $v (current)" >&2
                else
                    echo "    $v" >&2
                fi
            fi
        fi
    done
}

# Environment type declaration support
# Projects can declare their environment type in .python-env file
get_python_env_type() {
    if [[ -f .python-env ]]; then
        cat .python-env | head -1
    elif [[ -f environment.yml ]] || [[ -f conda.yaml ]]; then
        echo "conda"
    elif [[ -f uv.lock ]]; then
        echo "uv"
    else
        echo "venv"
    fi
}

# Activate the appropriate environment based on project type
activate_python_env() {
    local env_type=$(get_python_env_type)

    case "$env_type" in
        conda:*)
            # Format: conda:env_name
            local env_name="${env_type#conda:}"
            echo "Activating conda environment: $env_name" >&2
            conda activate "$env_name"
            ;;
        conda)
            # Look for env name in environment.yml
            if [[ -f environment.yml ]]; then
                local env_name=$(grep "^name:" environment.yml | awk '{print $2}')
                echo "Activating conda environment: $env_name" >&2
                conda activate "$env_name"
            else
                echo "Conda environment specified but no environment.yml found" >&2
                return 1
            fi
            ;;
        uv|venv)
            # Use venv with PATH
            if [[ -d .venv/bin ]]; then
                export PATH="$(pwd)/.venv/bin:$PATH"
                echo "Added .venv/bin to PATH" >&2
            elif [[ ! -d .venv ]]; then
                echo "No .venv found, creating with default Python..." >&2
                venv_create_new
                export PATH="$(pwd)/.venv/bin:$PATH"
            fi
            ;;
        *)
            echo "Unknown environment type: $env_type" >&2
            return 1
            ;;
    esac
}

# Export functions for testing
export -f venv_create_new
export -f venv_switch
export -f venv_list_new
export -f get_python_env_type
export -f activate_python_env