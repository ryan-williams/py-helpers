#!/usr/bin/env bash

# Helper functions for direnv setup

# Define if absent - append a line to .envrc if it's not already there
define_if_absent() {
    local line="$1"
    local file="${2:-.envrc}"

    if [ ! -f "$file" ]; then
        echo "$line" > "$file"
        echo "Created $file with: $line" >&2
    elif ! grep -Fq "$line" "$file"; then
        echo "$line" >> "$file"
        echo "Added to $file: $line" >&2
    else
        echo "Already in $file: $line" >&2
    fi
}
export -f define_if_absent

# Set up Python direnv - add the source line to .envrc
set_python_direnv() {
    local py_dir="$HOME/.rc/py"
    local with_source_up="${1:-false}"

    # Add source_up if requested or if parent has .envrc
    if [[ "$with_source_up" == "true" ]] || [[ -f "../.envrc" ]]; then
        define_if_absent "source_up" .envrc
    fi

    local source_line="source $py_dir/python-direnv.sh && setup_python_direnv"
    define_if_absent "$source_line" .envrc

    # Auto-allow if direnv is available
    if which direnv &>/dev/null; then
        direnv allow .
        echo "Direnv allowed for current directory" >&2
    fi
}
export -f set_python_direnv

# Aliases
alias dia="define_if_absent"
alias spd="set_python_direnv"
alias pyd="set_python_direnv"  # Alternative alias

# Create a basic .envrc with Python support
init_python_envrc() {
    set_python_direnv
}
export -f init_python_envrc
alias ipe="init_python_envrc"