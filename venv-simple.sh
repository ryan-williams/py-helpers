#!/usr/bin/env bash

# Simple venv management - just add .venv/bin to PATH and manage symlinks
# This goes in your .bashrc/.zshrc to always prefer local .venv over pyenv

# Add current directory's .venv/bin to PATH if it exists
# This should be called from your shell's prompt command or PROMPT_COMMAND
update_venv_path() {
    # Remove any previous .venv/bin from PATH
    PATH=$(echo "$PATH" | sed -E 's|[^:]*/.venv/bin:?||g')

    # Add current directory's .venv/bin if it exists
    if [[ -d "$PWD/.venv/bin" ]]; then
        export PATH="$PWD/.venv/bin:$PATH"
    fi
}

# Simple activation that just ensures .venv exists and is in PATH
auto_activate_venv() {
    if [[ -d ".venv" ]]; then
        # For UV projects with lock file, ensure synced
        if [[ -f "uv.lock" ]] && command -v uv &>/dev/null; then
            if [[ ! -d ".venv" ]] || [[ "uv.lock" -nt ".venv" ]]; then
                echo "UV project detected, syncing..." >&2
                uv sync --frozen --quiet 2>/dev/null || uv sync --quiet
            fi
        fi

        # Update PATH to include .venv/bin
        update_venv_path

        # Show what Python we're using (only if changed)
        if [[ "$LAST_VENV_DIR" != "$PWD" ]]; then
            export LAST_VENV_DIR="$PWD"
            local py_version=$(python --version 2>&1 | cut -d' ' -f2)
            echo "Using Python $py_version from .venv" >&2
        fi
    elif [[ -n "$LAST_VENV_DIR" ]]; then
        # We left a venv directory
        unset LAST_VENV_DIR
        update_venv_path  # This removes .venv from PATH
    fi
}

# Hook for cd to auto-activate
cd() {
    builtin cd "$@"
    auto_activate_venv
}

# Also run on shell startup for current directory
auto_activate_venv

# Export functions
export -f update_venv_path
export -f auto_activate_venv