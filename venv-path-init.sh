#!/usr/bin/env bash

# Simple PATH-based venv preference system
# Source this from your .bashrc/.zshrc to always prefer .venv over pyenv
#
# Requires: dedupe_path_var function (from ~/.rc/bash/vars/.vars-rc)

# Function to check and add .venv/bin to PATH when entering directories
venv_path_check() {
    # Preserve the exit status from the previous command
    local previous_exit_status=$?

    # Clean up ALL .venv/bin and .venv/cur/bin entries from PATH to prevent duplicates
    # Remove both absolute paths and relative paths
    local cleaned_path=$(echo "$PATH" | tr ':' '\n' | grep -v '/.venv/bin$' | grep -v '^\.venv/bin$' | grep -v '/.venv/cur/bin$' | grep -v '^\.venv/cur/bin$' | tr '\n' ':' | sed 's/:$//')

    # Check if current directory has .venv/bin (now a symlink to the active venv's bin)
    if [[ -d ".venv/bin" ]]; then
        # Add relative path to the front of PATH (simpler and more portable)
        PATH=".venv/bin:$cleaned_path"

        # For UV projects, ensure synced (but only once per venv)
        if [[ -f "uv.lock" ]] && command -v uv &>/dev/null; then
            # Use the actual venv directory for the marker, not the symlink
            local actual_venv=$(readlink .venv/cur)
            if [[ -n "$actual_venv" ]]; then
                local marker_file=".venv/${actual_venv}/.uv-synced"
                # Only sync if this specific venv hasn't been synced yet
                if [[ ! -f "$marker_file" ]]; then
                    echo "Syncing UV dependencies for ${actual_venv}..." >&2
                    # Tell UV to use .venv/cur as the environment
                    if UV_PROJECT_ENVIRONMENT=.venv/cur uv sync --frozen --quiet 2>/dev/null; then
                        touch "$marker_file"
                    fi
                fi
            fi
        fi
    else
        PATH="$cleaned_path"
    fi

    export PATH

    # Always dedupe PATH to prevent duplicates
    dedupe_path_var PATH

    # Return the preserved exit status
    return $previous_exit_status
}

# Option 1: Hook into cd (works in bash/zsh)
if [[ -n "$BASH_VERSION" ]]; then
    # Bash: use PROMPT_COMMAND
    if [[ ! "$PROMPT_COMMAND" =~ venv_path_check ]]; then
        PROMPT_COMMAND="venv_path_check${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
elif [[ -n "$ZSH_VERSION" ]]; then
    # Zsh: use precmd hook
    autoload -U add-zsh-hook
    add-zsh-hook precmd venv_path_check
fi

# Option 2: Simple cd wrapper (fallback)
venv_cd() {
    builtin cd "$@"
    venv_path_check
}

# Check on shell startup
venv_path_check

# Export the function so it's available
export -f venv_path_check 2>/dev/null || true