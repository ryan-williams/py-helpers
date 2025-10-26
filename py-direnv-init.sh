#!/usr/bin/env bash

# Setup Python projects with direnv and multi-version support
# Creates minimal .envrc files that source shared helpers

# Source venv helpers if not already loaded
if ! type -t venv_init &>/dev/null; then
    py_dir="$HOME/.rc/py"
    [ -f "$py_dir/venv-helpers.sh" ] && source "$py_dir/venv-helpers.sh"
fi

# Initialize Python project with direnv - creates .envrc and venvs
# Usage:
#   py_direnv_init          # Default: creates .venv with current Python
#   py_direnv_init 3.13     # Single version
#   py_direnv_init 3.11 3.12 3.13  # Multiple versions
py_direnv_init() {
    # Collect all arguments as space-separated versions
    local versions="$*"
    local default_version="3.13"  # Default Python to activate if multiple
    local has_uv_lock=false

    # Check for uv.lock to determine project type
    if [[ -f "uv.lock" ]]; then
        has_uv_lock=true
        echo "Detected uv.lock - will use uv sync for dependencies" >&2
    fi

    echo "Setting up Python project with direnv..." >&2

    # Step 0: Handle existing .venv directory
    if [[ -d ".venv" ]] && [[ ! -L ".venv" ]]; then
        # Check if this is already the new structure (.venv/X.Y.Z/)
        if [[ -d ".venv/cur" ]] || ls .venv/[0-9]* &>/dev/null 2>&1; then
            echo "Found existing .venv with versioned structure" >&2
        # Check if this is old-style .venv (direct venv directory)
        elif [[ -f ".venv/bin/python" ]]; then
            echo "Found existing .venv directory (old format)" >&2

            # Detect the Python version in the existing venv
            local existing_version=$(.venv/bin/python --version 2>&1 | awk '{print $2}')

            echo "  Detected Python $existing_version" >&2
            echo "  Converting to new structure: .venv/$existing_version/" >&2

            # Move the old venv to a temp location
            mv .venv ".venv.tmp.$$"

            # Create new .venv directory with versioned structure
            mkdir -p .venv

            # Move the venv into the new structure
            mv ".venv.tmp.$$" ".venv/$existing_version"

            # Set up symlinks and marker file using shared helper
            venv_set_current "$existing_version"

            echo "  Converted to .venv/$existing_version/ with symlinks" >&2

            # If no versions specified, we're done
            if [[ -z "$versions" ]]; then
                echo "  Existing venv preserved and converted to versioned format" >&2
                versions=""  # Don't create new venvs
            else
                echo "  Will create additional venvs for: $versions" >&2
            fi
        else
            echo "  Warning: .venv exists but structure unclear, backing up to .venv.backup" >&2
            mv .venv .venv.backup
        fi
    fi

    # Step 1: Create venvs if versions specified
    if [[ -n "$versions" ]]; then
        echo "Initializing Python venvs: $versions" >&2
        venv_init "$versions"
    elif [[ ! -d ".venv" ]] && [[ ! -L ".venv" ]]; then
        # No .venv exists and no versions specified - create default with versioned structure
        echo "Creating default versioned .venv..." >&2
        venv_create  # This creates .venv/X.Y.Z structure with symlinks

        # Install dependencies if needed
        if [[ "$has_uv_lock" == "true" ]]; then
            echo "  Installing dependencies with uv sync..." >&2
            # Set UV_PROJECT_ENVIRONMENT to .venv (UV will follow symlinks)
            UV_PROJECT_ENVIRONMENT=".venv" uv sync --frozen 2>&1 | tail -5
        elif [[ -f "pyproject.toml" ]] && command -v uv &>/dev/null; then
            uv pip install -e . --python .venv/bin/python
        elif [[ -f "requirements.txt" ]] && command -v uv &>/dev/null; then
            uv pip install -r requirements.txt --python .venv/bin/python
        fi
    fi

    # Step 2: Create or repair .envrc
    if [[ ! -f ".envrc" ]]; then
        # Create minimal .envrc that sources and calls the init function
        cat > .envrc << 'EOF'
# Python environment - activates .venv symlink
# To switch versions: uvsw 3.12 (changes symlink)
source_up 2>/dev/null || true
source $HOME/.rc/py/py-direnv-rc.sh && py_direnv_rc
EOF
        echo "Created .envrc with Python support" >&2
    else
        echo ".envrc already exists" >&2
        # Check if it has the required py-direnv-rc line
        if ! grep -q "py-direnv-rc.sh.*py_direnv_rc" .envrc; then
            # Check if there's existing .venv structure that needs management
            if [[ -d ".venv" ]] && (ls .venv/[0-9]* &>/dev/null 2>&1 || [[ -d ".venv/cur" ]] || [[ -L ".venv/bin" ]]); then
                echo "  Missing Python venv management line, adding..." >&2
                cat >> .envrc << 'EOF'
# Python environment - activates .venv symlink
# To switch versions: uvsw 3.12 (changes symlink)
source $HOME/.rc/py/py-direnv-rc.sh && py_direnv_rc
EOF
                echo "  Updated .envrc with Python support" >&2
            else
                echo "  .envrc exists but .venv structure needs initialization" >&2
                echo "  (will preserve existing .envrc and set up .venv)" >&2
            fi
        else
            echo "  .envrc already has Python support" >&2
        fi
    fi

    # Step 3: Set default version if multiple venvs exist
    if [[ -n "$versions" ]] && [[ "$versions" == *" "* ]]; then
        # Multiple versions - set up default symlink
        local first_version="${default_version}"
        if find_venv "$first_version" &>/dev/null; then
            local venv_dir=$(find_venv "$first_version")
            ln -sfn "$venv_dir" .venv
            echo "Set default: .venv -> $venv_dir" >&2
        fi
    fi

    # Step 4: Allow direnv
    if which direnv &>/dev/null; then
        direnv allow .
        echo "Direnv allowed for current directory" >&2
        echo "" >&2
        echo "Project setup complete!" >&2

        # Show available venvs if multiple
        local venv_count=$(ls -d .venv[0-9]* 2>/dev/null | wc -l)
        if [[ $venv_count -gt 1 ]]; then
            echo "" >&2
            echo "Available Python versions:" >&2
            for venv in .venv[0-9]*; do
                if [[ -d "$venv" ]]; then
                    local py_version=$("$venv/bin/python" --version 2>&1 | cut -d' ' -f2)
                    local marker=""
                    if [[ -L ".venv" ]] && [[ "$(readlink .venv)" == "$venv" ]]; then
                        marker=" [default]"
                    fi
                    echo "  ${venv#.venv} -> Python $py_version$marker" >&2
                fi
            done
            echo "" >&2
            echo "To switch: PYTHON_VERSION=3.12 direnv reload" >&2
        fi
    fi
}

# Quick aliases with sensible defaults
defn spd py_direnv_init     # Setup Python Direnv
defn spdm "py_direnv_init 3.11 3.12 3.13"  # Setup Python Direnv Multi-version
defn spd312 "py_direnv_init 3.12"
defn spd313 "py_direnv_init 3.13"

export -f py_direnv_init
