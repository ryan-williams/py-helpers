#!/usr/bin/env bash

# Python venv version management helpers for uv
# Provides easy switching between Python versions in projects

# Source the PATH management functions (required for vsw and va commands)
py_dir="$(dirname "${BASH_SOURCE[0]}")"
source "$py_dir/venv-path-init.sh"  # Required - fail if missing
#
# Venv structure: .venv/X.Y.Z/ with symlinks for current version
#
# Available commands:
#   vvi [versions]        - Initialize multiple venvs (e.g., vvi 3.11 3.12 3.13)
#   vc [version]          - Create venv with specific Python version (e.g., vc 3.12)
#   vsw [prefix]          - Switch to Python version by prefix (e.g., vsw 3.12)
#   vl                    - List available venvs in current directory
#   va [version]          - Activate Python venv (creates/switches if needed)
#   py312/py313/py311/py310 - Quick switches to specific Python versions
#   vei                   - Show current Python environment info
#   vclean                - Clean up old venvs (keeps currently active)
#   vconv                 - Convert unversioned .venv to versioned format
#   spd/spdm              - Setup .envrc for Python projects with direnv
#
# Environment variables:
#   PYTHON_VERSION        - Set to use specific Python version (e.g., export PYTHON_VERSION=3.12)
#
# Usage options:
#   1. Simple PATH-based (recommended): Add to .bashrc/.zshrc:
#      source $HOME/.rc/py/venv-path-init.sh
#      Then .venv/bin will be preferred automatically when you cd
#
#   2. With direnv: Run 'spd' or 'spdm' to create .envrc
#      Switch versions: PYTHON_VERSION=3.12 direnv reload

# Ensure pip wrapper exists in UV-created venvs (no longer needed with new structure)
# pip wrapper is created during venv_create for each version

# Get the full Python version for a given spec
# e.g., "3.12" -> "3.12.7", "3.12.x" -> "3.12.7", "3.13" -> "3.13.5"
get_python_full_version() {
    local spec="$1"
    local full_version=""

    # Remove .x suffix if present
    spec="${spec%.x}"

    # If UV is available, ask it which Python it would actually use
    if command -v uv &>/dev/null; then
        # Create a temp venv to see which Python UV actually uses
        local temp_dir=$(mktemp -d)
        local uv_output=$(uv venv "$temp_dir" --python "$spec" 2>&1)
        rm -rf "$temp_dir"

        # Extract version from "Using CPython 3.13.5" or "Using CPython 3.13.5 interpreter at: ..."
        # Use grep and sed to extract just the version number
        full_version=$(echo "$uv_output" | grep "Using CPython" | sed -n 's/.*CPython \([0-9.]*\).*/\1/p' | head -1)
    fi

    # Fallback: try to find installed Python
    if [[ -z "$full_version" ]]; then
        if command -v "python${spec}" &>/dev/null; then
            full_version=$("python${spec}" --version 2>&1 | awk '{print $2}')
        else
            echo "Warning: Cannot determine full version for Python ${spec}" >&2
            full_version="$spec"
        fi
    fi

    echo "$full_version"
}

# Initialize multiple Python venvs at once
# Usage: vvi 3.11 3.12 3.13
venv_init() {
    local versions="${*:-3.13}"
    # Convert space-separated arguments to array
    local VERSION_ARRAY=($versions)

    echo "Initializing Python venvs for: ${VERSION_ARRAY[@]}" >&2

    for spec in "${VERSION_ARRAY[@]}"; do
        # Trim whitespace
        spec=$(echo "$spec" | xargs)
        venv_create "$spec"
    done

    echo "Done! Available venvs:" >&2
    venv_list
}
defn vvi venv_init  # Initialize multiple venvs

# Old-style venv conversion removed - use new .venv/X.Y.Z structure

# Create venv with specific Python version (uses uv if available)
# Can create multiple venvs: vc 3.10 3.11 or vc 3.{10,11}
venv_create() {
    # If no arguments, use default
    if [[ $# -eq 0 ]]; then
        set -- "3.13"
    fi

    local last_version=""

    # Process each Python version argument
    for py_spec in "$@"; do
        local full_version=$(get_python_full_version "$py_spec")

        # Use .venv/X.Y.Z structure with .venv/cur as symlink
        mkdir -p .venv
        local venv_name=".venv/${full_version}"

        if [[ -d "$venv_name" ]]; then
            echo "Venv $venv_name already exists" >&2
        else
            echo "Creating $venv_name with Python $py_spec..." >&2
            if command -v uv &>/dev/null; then
                uv venv "$venv_name" --python "$py_spec"

                # Create pip wrapper for UV projects
                if [[ ! -f "$venv_name/bin/pip" ]]; then
                    cat > "$venv_name/bin/pip" <<'EOF'
#!/bin/bash
# Wrapper for uv pip to handle common pip commands
# Get the directory where this script lives (the venv's bin directory)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$(dirname "$SCRIPT_DIR")"

if [[ "$1" == "--version" ]] || [[ "$1" == "-V" ]]; then
    echo "pip (uv wrapper)"
    uv --version
else
    # Pass the command with --python flag in the right place
    # uv pip COMMAND --python PATH args...
    if [[ -n "$1" ]]; then
        COMMAND="$1"
        shift
        exec uv pip "$COMMAND" --python "$VENV_DIR/bin/python" "$@"
    else
        exec uv pip "$@"
    fi
fi
EOF
                    chmod +x "$venv_name/bin/pip"
                fi
            else
                python${py_spec} -m venv "$venv_name"
            fi

            # Install deps if project files exist (only for non-uv.lock projects)
            if [[ -f "uv.lock" ]] && command -v uv &>/dev/null; then
                echo "UV project detected, dependencies will sync when activated" >&2
            elif [[ -f "pyproject.toml" ]] && command -v uv &>/dev/null; then
                echo "Installing dependencies with uv..." >&2
                uv pip install -e . --python "$venv_name/bin/python"
            elif [[ -f "pyproject.toml" ]] && [[ -f "$venv_name/bin/pip" ]]; then
                echo "Installing dependencies with pip..." >&2
                "$venv_name/bin/pip" install -e .
            elif [[ -f "requirements.txt" ]]; then
                echo "Installing requirements..." >&2
                if command -v uv &>/dev/null; then
                    uv pip install -r requirements.txt --python "$venv_name/bin/python"
                else
                    "$venv_name/bin/pip" install -r requirements.txt
                fi
            fi
        fi

        last_version="${full_version}"
    done

    # Set direct symlinks to the last created venv (avoid nested symlinks)
    if [[ -n "$last_version" ]]; then
        venv_set_current "${last_version}"

        # Trigger path check to activate it
        venv_path_check
    fi
}
defn vc venv_create

# Set current venv by creating symlinks and marker file
# Args: version (e.g., "3.13.7")
venv_set_current() {
    local version="$1"

    # Create direct symlinks to version directories (not through cur)
    # Must remove existing directories first - ln -sfn can't replace dirs with symlinks
    for item in bin lib include pyvenv.cfg; do
        if [[ -e ".venv/$item" ]] && [[ ! -L ".venv/$item" ]]; then
            rm -rf ".venv/$item"
        fi
    done
    ln -sfn "${version}/bin" .venv/bin
    ln -sfn "${version}/lib" .venv/lib
    ln -sfn "${version}/include" .venv/include
    ln -sfn "${version}/pyvenv.cfg" .venv/pyvenv.cfg

    # Store current version in a file for reference
    echo "${version}" > .venv/current

    # Create lock file if it doesn't exist
    if [[ ! -e .venv/.lock ]]; then
        touch .venv/.lock
        chmod 777 .venv/.lock
    fi

    echo "Set current version to ${version}" >&2
}
export -f venv_set_current

# Find venv by pattern (e.g., "12" matches ".venv3.12.7", "3.12" also works)
find_venv() {
    local pattern="$1"

    # Normalize pattern: "13" -> "3.13", "3.13" stays "3.13"
    if [[ "$pattern" =~ ^[0-9]{2}$ ]]; then
        # Two digits like "13" -> interpret as "3.13"
        pattern="3.$pattern"
    fi

    # Check in .venv directory
    if [[ ! -d ".venv" ]]; then
        return 1
    fi

    # First try exact match
    if [[ -d ".venv/${pattern}" ]]; then
        echo ".venv/${pattern}"
        return 0
    fi

    # Then try prefix match with the normalized pattern
    for venv in .venv/${pattern}*; do
        if [[ -d "$venv" ]] && [[ "$venv" != ".venv/${pattern}*" ]] && [[ "$venv" != ".venv/cur" ]]; then
            echo "$venv"
            return 0
        fi
    done

    # No match found
    return 1
}

# Switch to a specific Python version venv
venv_switch() {
    local py_prefix="${1:-3.13}"

    # Normalize pattern for consistency
    if [[ "$py_prefix" =~ ^[0-9]{2}$ ]]; then
        py_prefix="3.$py_prefix"
    fi

    # Try to find existing venv with this prefix
    local venv_name=$(find_venv "$py_prefix" 2>&1)

    # Check if find_venv returned an error (multiple matches)
    if [[ "$venv_name" == Error:* ]]; then
        echo "$venv_name" >&2
        return 1
    fi

    if [[ -z "$venv_name" ]]; then
        # Doesn't exist, create it
        echo "No venv found for '$py_prefix', creating new one..." >&2
        venv_create "$py_prefix"
        venv_name=$(find_venv "$py_prefix")
    fi

    if [[ -z "$venv_name" ]]; then
        echo "Error: Could not find or create venv for '$py_prefix'" >&2
        return 1
    fi

    # Update direct symlinks (no cur symlink to avoid nested symlinks)
    local venv_basename=$(basename "$venv_name")
    # Must remove existing directories first - ln -sfn can't replace dirs with symlinks
    for item in bin lib include pyvenv.cfg; do
        if [[ -e ".venv/$item" ]] && [[ ! -L ".venv/$item" ]]; then
            rm -rf ".venv/$item"
        fi
    done
    ln -sfn "${venv_basename}/bin" .venv/bin
    ln -sfn "${venv_basename}/lib" .venv/lib
    ln -sfn "${venv_basename}/include" .venv/include
    ln -sfn "${venv_basename}/pyvenv.cfg" .venv/pyvenv.cfg

    # Store current version in file
    echo "${venv_basename}" > .venv/current

    local actual_version=$("$venv_name/bin/python" --version 2>&1 | awk '{print $2}')
    echo "Switched to Python $actual_version (current: $venv_basename)" >&2

    # Don't source activate script - let venv_path_check handle PATH
    # This prevents duplicate/absolute path entries
    venv_path_check  # Update PATH using our dedupe logic
}
defn vsw venv_switch  # switch Python venv
defn vw venv_switch   # shorter alias for vsw
venv_list() {
    echo "Available venvs:" >&2
    if [[ ! -d ".venv" ]]; then
        echo "  No venvs found (no .venv directory)" >&2
        return
    fi

    local current=""
    if [[ -f ".venv/current" ]]; then
        current=$(cat .venv/current)
    fi

    for venv in .venv/*/; do
        if [[ -d "$venv" ]] && [[ -f "$venv/bin/python" ]]; then
            local venv_name=$(basename "$venv")
            # Skip non-version directories
            if [[ ! "$venv_name" =~ ^[0-9] ]]; then
                continue
            fi
            local py_version=$("$venv/bin/python" --version 2>&1 | cut -d' ' -f2)
            local marker=""
            if [[ "$venv_name" == "$current" ]]; then
                marker=" [active]"
            fi
            echo "  $venv_name -> Python $py_version$marker"
        fi
    done
}
defn vl venv_list  # list venvs

# Activate venv - uses .venv/bin in PATH
activate_venv() {
    local version="${1:-}"

    if [[ -n "$version" ]]; then
        # Version specified - delegate to venv_switch
        venv_switch "$version"
    elif [[ ! -f ".venv/current" ]] && [[ -d ".venv" ]]; then
        # No current version set - find or create default
        local existing_venv=$(ls -d .venv/[0-9]*/ 2>/dev/null | head -1)
        if [[ -n "$existing_venv" ]]; then
            # Found versioned venv - switch to it
            venv_switch "$(basename "$existing_venv")"
        else
            # No venvs at all - create with default Python
            venv_switch  # Uses default (3.13)
        fi
    elif [[ ! -d ".venv" ]]; then
        # No .venv at all - create with default Python
        venv_switch  # Uses default (3.13)
    fi

    # Don't source activate script - let venv_path_check handle PATH
    venv_path_check  # Update PATH using our dedupe logic
    echo "Activated $(python --version 2>&1)" >&2
}
defn va activate_venv  # activate venv (respects versioned scheme)

# Quick Python version aliases (most common versions)
defn py312 "venv_switch 3.12"
defn py313 "venv_switch 3.13"
defn py311 "venv_switch 3.11"
defn py310 "venv_switch 3.10"


# Show current Python version and venv info
venv_info() {
    echo "Python Environment Info:" >&2
    echo "========================" >&2

    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "Active venv: $VIRTUAL_ENV"
        echo "Python: $(python --version)"
    elif [[ -d ".venv" ]]; then
        echo "Venv exists: .venv (not activated)"
        if [[ -L ".venv" ]]; then
            echo "Symlink to: $(readlink .venv)"
        fi
        echo "Python: $(.venv/bin/python --version 2>&1)"
    else
        echo "No venv in current directory"
        echo "System Python: $(python3 --version)"
    fi

    # Show available venvs
    local venv_count=$(ls -d .venv* 2>/dev/null | wc -l)
    if [[ $venv_count -gt 0 ]]; then
        echo ""
        venv_list
    fi
}
defn vei venv_info  # venv info

# Cleanup old venvs (keep only specified or currently active)
venv_clean() {
    local keep_current=true
    local current_venv=""

    if [[ -f ".venv/current" ]]; then
        current_venv=$(cat .venv/current)
    fi

    echo "Cleaning up venvs..." >&2
    if [[ ! -d ".venv" ]]; then
        echo "  No venvs to clean (no .venv directory)" >&2
        return
    fi

    for venv in .venv/*/; do
        if [[ -d "$venv" ]]; then
            local venv_basename=$(basename "$venv")
            # Skip non-version directories
            if [[ ! "$venv_basename" =~ ^[0-9] ]]; then
                continue
            fi
            if [[ "$venv_basename" == "$current_venv" ]]; then
                echo "  Keeping $venv_basename (currently active)"
            else
                echo "  Removing $venv_basename"
                rm -rf "$venv"
            fi
        fi
    done
}
defn vclean venv_clean  # clean up venvs

# pyenv deactivation removed - no longer using pyenv

# Simple PATH-based activation (no direnv needed)
# Just ensures .venv/bin is in PATH when you cd to a directory
enable_venv_auto_path() {
    source "$HOME/.rc/py/venv-path-init.sh"
    echo "Enabled automatic .venv PATH preference" >&2
    echo "Now when you cd to a directory with .venv, it will be used automatically" >&2
}
defn vpath enable_venv_auto_path  # Enable simple PATH-based venv activation

# Note: Use 'spd' instead for setting up Python projects with direnv
# spd creates both .envrc AND the venvs
