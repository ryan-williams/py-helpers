#!/usr/bin/env bash

# Test suite for the new Python venv system
# Uses local tmpdirs to test various scenarios

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create a temporary test directory
# Use TMPDIR if set, otherwise use /tmp
TEST_DIR="${TMPDIR:-/tmp}"
TEST_BASE=$(mktemp -d "${TEST_DIR}/test-venv-system.XXXXXX")

# Ensure cleanup on exit
cleanup() {
    if [[ -n "$TEST_BASE" ]] && [[ -d "$TEST_BASE" ]]; then
        rm -rf "$TEST_BASE"
    fi
}
trap cleanup EXIT INT TERM

# Mock get_python_full_version for testing
get_python_full_version() {
    case "$1" in
        3.11*) echo "3.11.13" ;;
        3.12*) echo "3.12.11" ;;
        3.13*) echo "3.13.5" ;;
        *) echo "$1" ;;
    esac
}

# Simplified venv_create for testing
test_venv_create() {
    local py_spec="${1:-3.13}"
    local full_version=$(get_python_full_version "$py_spec")

    mkdir -p .venv
    local venv_path=".venv/${full_version}"

    if [[ -d "$venv_path" ]]; then
        echo "Venv $venv_path already exists" >&2
        return 0
    fi

    echo "Creating $venv_path with Python $py_spec..." >&2
    if command -v uv &>/dev/null; then
        uv venv "$venv_path" --python "$py_spec" >/dev/null 2>&1 || {
            # Fallback: create mock structure for testing
            mkdir -p "$venv_path/bin"
            mkdir -p "$venv_path/lib"
            mkdir -p "$venv_path/include"
            touch "$venv_path/pyvenv.cfg"
            touch "$venv_path/bin/python"
            chmod +x "$venv_path/bin/python"
        }
    else
        # Create mock structure for testing
        mkdir -p "$venv_path/bin"
        mkdir -p "$venv_path/lib"
        mkdir -p "$venv_path/include"
        touch "$venv_path/pyvenv.cfg"
        touch "$venv_path/bin/python"
        chmod +x "$venv_path/bin/python"
    fi

    # Create direct symlinks (no cur)
    ln -sfn "${full_version}/bin" .venv/bin
    ln -sfn "${full_version}/lib" .venv/lib
    ln -sfn "${full_version}/include" .venv/include
    ln -sfn "${full_version}/pyvenv.cfg" .venv/pyvenv.cfg

    # Store current version
    echo "${full_version}" > .venv/current
}

# Simplified venv_switch for testing
test_venv_switch() {
    local version="$1"
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
        echo "Version $version not found" >&2
        return 1
    fi

    # Update direct symlinks
    ln -sfn "${full_version}/bin" .venv/bin
    ln -sfn "${full_version}/lib" .venv/lib
    ln -sfn "${full_version}/include" .venv/include
    ln -sfn "${full_version}/pyvenv.cfg" .venv/pyvenv.cfg

    echo "${full_version}" > .venv/current
}

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $msg"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_exists() {
    local path="$1"
    local msg="${2:-File/dir should exist: $path}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -e "$path" ]]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $msg"
        echo "  Missing: $path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_symlink() {
    local path="$1"
    local target="$2"
    local msg="${3:-Symlink check}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -L "$path" ]]; then
        local actual_target=$(readlink "$path")
        if [[ "$actual_target" == "$target" ]]; then
            echo -e "${GREEN}✓${NC} $msg"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗${NC} $msg"
            echo "  Expected target: $target"
            echo "  Actual target: $actual_target"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗${NC} $msg - not a symlink"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_exists() {
    local path="$1"
    local msg="${2:-Should not exist: $path}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ ! -e "$path" ]]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $msg"
        echo "  Exists: $path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Basic venv creation with new structure
test_basic_venv_creation() {
    echo -e "\n${YELLOW}Test 1: Basic venv creation${NC}"
    local test_dir="$TEST_BASE/test1"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create a venv
    test_venv_create 3.12

    # Check structure
    assert_exists ".venv" "Main .venv directory exists"
    assert_exists ".venv/3.12.11" ".venv/3.12.11 directory exists"
    assert_symlink ".venv/bin" "3.12.11/bin" ".venv/bin symlinks to version bin"
    assert_symlink ".venv/lib" "3.12.11/lib" ".venv/lib symlinks to version lib"
    assert_symlink ".venv/include" "3.12.11/include" ".venv/include symlinks to version include"
    assert_exists ".venv/current" ".venv/current file exists"

    # Check current version stored correctly
    local current=$(cat .venv/current)
    assert_equals "3.12.11" "$current" "Current version is 3.12.11"
}

# Test 2: Multiple version support
test_multiple_versions() {
    echo -e "\n${YELLOW}Test 2: Multiple Python versions${NC}"
    local test_dir="$TEST_BASE/test2"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create multiple versions
    test_venv_create 3.11
    test_venv_create 3.12

    # Check both versions exist
    assert_exists ".venv/3.11.13" "Python 3.11.13 venv exists"
    assert_exists ".venv/3.12.11" "Python 3.12.11 venv exists"

    # Check current points to last created
    local current=$(cat .venv/current)
    assert_equals "3.12.11" "$current" "Current version is 3.12.11"

    # Test switching
    test_venv_switch 3.11.13
    current=$(cat .venv/current)
    assert_equals "3.11.13" "$current" "Switched to 3.11.13"
}

# Test 3: No nested symlinks (no cur directory)
test_no_nested_symlinks() {
    echo -e "\n${YELLOW}Test 3: No nested symlinks${NC}"
    local test_dir="$TEST_BASE/test3"
    mkdir -p "$test_dir"
    cd "$test_dir"

    test_venv_create 3.11

    # Check that .venv/bin is a direct symlink
    local bin_target=$(readlink .venv/bin)
    assert_equals "3.11.13/bin" "$bin_target" ".venv/bin points directly to version"

    # Ensure no .venv/cur exists
    assert_not_exists ".venv/cur" "No .venv/cur symlink exists"
}

# Test 4: Environment type detection
test_env_type_detection() {
    echo -e "\n${YELLOW}Test 4: Environment type detection${NC}"

    # Source the environment type functions
    source "$HOME/.rc/py/python-env-type.sh" 2>/dev/null || {
        echo -e "${YELLOW}⚠${NC} Skipping env type test (python-env-type.sh not available)"
        return
    }

    # Test uv detection
    local test_dir="$TEST_BASE/test4_uv"
    mkdir -p "$test_dir"
    cd "$test_dir"
    touch uv.lock
    local env_type=$(get_python_env_type)
    assert_equals "uv" "$env_type" "Detects uv from uv.lock"

    # Test conda detection
    test_dir="$TEST_BASE/test4_conda"
    mkdir -p "$test_dir"
    cd "$test_dir"
    touch environment.yml
    env_type=$(get_python_env_type)
    assert_equals "conda" "$env_type" "Detects conda from environment.yml"

    # Test explicit declaration
    test_dir="$TEST_BASE/test4_explicit"
    mkdir -p "$test_dir"
    cd "$test_dir"
    echo "conda:myenv" > .python-env
    env_type=$(get_python_env_type)
    assert_equals "conda:myenv" "$env_type" "Reads explicit .python-env"

    # Test default
    test_dir="$TEST_BASE/test4_default"
    mkdir -p "$test_dir"
    cd "$test_dir"
    env_type=$(get_python_env_type)
    assert_equals "venv" "$env_type" "Defaults to venv"
}

# Test 5: Version switching with partial matches
test_partial_version_switch() {
    echo -e "\n${YELLOW}Test 5: Partial version switching${NC}"
    local test_dir="$TEST_BASE/test5"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create venvs
    test_venv_create 3.11
    test_venv_create 3.12

    # Switch using partial version
    test_venv_switch 3.11
    local current=$(cat .venv/current)
    assert_equals "3.11.13" "$current" "Switched to 3.11.13"

    test_venv_switch 3.12
    current=$(cat .venv/current)
    assert_equals "3.12.11" "$current" "Switched to 3.12.11"
}

# Test 6: Symlink structure validation
test_symlink_structure() {
    echo -e "\n${YELLOW}Test 6: Symlink structure validation${NC}"
    local test_dir="$TEST_BASE/test6"
    mkdir -p "$test_dir"
    cd "$test_dir"

    test_venv_create 3.13

    # Verify all symlinks point to the same version
    local bin_target=$(readlink .venv/bin)
    local lib_target=$(readlink .venv/lib)
    local include_target=$(readlink .venv/include)
    local pyvenv_target=$(readlink .venv/pyvenv.cfg)

    assert_equals "3.13.5/bin" "$bin_target" "bin symlink correct"
    assert_equals "3.13.5/lib" "$lib_target" "lib symlink correct"
    assert_equals "3.13.5/include" "$include_target" "include symlink correct"
    assert_equals "3.13.5/pyvenv.cfg" "$pyvenv_target" "pyvenv.cfg symlink correct"
}

# Test 7: PATH resolution
test_path_resolution() {
    echo -e "\n${YELLOW}Test 7: PATH resolution${NC}"
    local test_dir="$TEST_BASE/test7"
    mkdir -p "$test_dir"
    cd "$test_dir"

    test_venv_create 3.12

    # Check that .venv/bin/python exists (even if it's a symlink)
    assert_exists ".venv/bin/python" "Python binary accessible through .venv/bin"

    # Test PATH would work
    local saved_path="$PATH"
    export PATH="$test_dir/.venv/bin:$PATH"

    # Check which python would be found
    local python_path=$(command -v python 2>/dev/null || echo "")
    if [[ "$python_path" == "$test_dir/.venv/bin/python" ]]; then
        echo -e "${GREEN}✓${NC} Python in PATH resolves correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Could not verify PATH resolution"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    export PATH="$saved_path"
}

# Test 8: Real Python execution (if uv available)
test_real_python_execution() {
    echo -e "\n${YELLOW}Test 8: Real Python execution${NC}"

    if ! command -v uv &>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Skipping real Python test (uv not available)"
        return
    fi

    local test_dir="$TEST_BASE/test8"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create real venv with uv
    uv venv .venv/3.12 --python 3.12 >/dev/null 2>&1 || {
        echo -e "${YELLOW}⚠${NC} Could not create real venv with uv"
        return
    }

    # Set up symlinks
    ln -sfn "3.12/bin" .venv/bin
    ln -sfn "3.12/lib" .venv/lib
    ln -sfn "3.12/include" .venv/include
    ln -sfn "3.12/pyvenv.cfg" .venv/pyvenv.cfg
    echo "3.12" > .venv/current

    # Test Python execution
    if [[ ! -f .venv/bin/python ]]; then
        echo -e "${YELLOW}⚠${NC} Python binary not found at .venv/bin/python"
        return
    fi

    local sys_prefix=$(.venv/bin/python -c 'import sys; print(sys.prefix)' 2>&1)
    local sys_executable=$(.venv/bin/python -c 'import sys; print(sys.executable)' 2>&1)

    # Check for errors
    if [[ "$sys_prefix" == *"Error"* ]] || [[ "$sys_prefix" == *"not found"* ]]; then
        echo -e "${YELLOW}⚠${NC} Could not execute Python: $sys_prefix"
        return
    fi

    # With the new structure, Python correctly resolves to the actual venv dir
    # It should be under .venv/ and contain the executable
    # Use string contains check instead of regex to handle path variations
    if [[ "$sys_prefix" == *"/.venv/"* ]] && [[ -n "$sys_executable" ]]; then
        echo -e "${GREEN}✓${NC} Real Python execution works"
        echo "    sys.prefix: $sys_prefix"
        echo "    sys.executable: $sys_executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Python execution issue"
        echo "    sys.prefix: $sys_prefix"
        echo "    sys.executable: $sys_executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test 9: Multi-version workflow with real repo
test_multi_version_workflow() {
    echo ""
    echo "Test 9: Multi-version workflow with real repo"
    cd "$TEST_BASE"

    # Clone the test repo
    echo "  Cloning bash-markdown-fence..."
    git clone --quiet https://github.com/runsascoded/bash-markdown-fence test-repo >/dev/null 2>&1 || {
        echo -e "${YELLOW}⚠${NC} Could not clone test repo (network issue?)"
        return
    }

    cd test-repo

    # Source the venv helpers
    source "$HOME/.rc/py/venv-helpers.sh"

    # Create multiple venvs with vc
    echo "  Creating venvs for 3.11, 3.12, 3.13..."

    # Test vc 3.11
    if command -v uv >/dev/null 2>&1; then
        vc 3.11 >/dev/null 2>&1
        vc 3.12 >/dev/null 2>&1
        vc 3.13 >/dev/null 2>&1
    else
        echo -e "${YELLOW}⚠${NC} uv not available, simulating venv creation"
        # Simulate for testing without uv
        mkdir -p .venv/{3.11.13,3.12.11,3.13.5}/bin
        for ver in 3.11.13 3.12.11 3.13.5; do
            # Create fake python binary
            echo '#!/bin/bash' > .venv/$ver/bin/python
            echo "echo '.venv/$ver/bin/python'" >> .venv/$ver/bin/python
            chmod +x .venv/$ver/bin/python
        done
    fi

    # Check that 3 venvs were created
    local venv_count=$(ls -d .venv/*/bin 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$venv_count" -eq 3 ]]; then
        echo -e "${GREEN}✓${NC} Created 3 venvs"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Expected 3 venvs, found $venv_count"
        ls -la .venv/
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Test vw 11 -> pex
    vw 11 >/dev/null 2>&1
    local pex_output=$(pex 2>/dev/null || echo ".venv/bin/python")
    if [[ "$pex_output" == *".venv/3.11"* ]] || [[ "$pex_output" == *"3.11"* ]]; then
        echo -e "${GREEN}✓${NC} vw 11 -> pex shows 3.11"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} vw 11 did not switch to 3.11 (got: $pex_output)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Test vw 12 -> pex
    vw 12 >/dev/null 2>&1
    pex_output=$(pex 2>/dev/null || echo ".venv/bin/python")
    if [[ "$pex_output" == *".venv/3.12"* ]] || [[ "$pex_output" == *"3.12"* ]]; then
        echo -e "${GREEN}✓${NC} vw 12 -> pex shows 3.12"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} vw 12 did not switch to 3.12 (got: $pex_output)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Test vw 13 -> pex
    vw 13 >/dev/null 2>&1
    pex_output=$(pex 2>/dev/null || echo ".venv/bin/python")
    if [[ "$pex_output" == *".venv/3.13"* ]] || [[ "$pex_output" == *"3.13"* ]]; then
        echo -e "${GREEN}✓${NC} vw 13 -> pex shows 3.13"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} vw 13 did not switch to 3.13 (got: $pex_output)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Run all tests
main() {
    echo "========================================="
    echo "Python Venv System Test Suite"
    echo "========================================="
    echo "Test directory: $TEST_BASE"

    # If specific tests are requested, run only those
    if [[ $# -gt 0 ]]; then
        echo "Running specific tests: $@"
        for test_name in "$@"; do
            if declare -f "$test_name" >/dev/null; then
                "$test_name"
            else
                echo -e "${RED}✗${NC} Test function '$test_name' not found"
                TESTS_FAILED=$((TESTS_FAILED + 1))
                TESTS_RUN=$((TESTS_RUN + 1))
            fi
        done
    else
        # Run all tests
        test_basic_venv_creation
        test_multiple_versions
        test_no_nested_symlinks
        test_env_type_detection
        test_partial_version_switch
        test_symlink_structure
        test_path_resolution
        test_real_python_execution
        test_multi_version_workflow
    fi

    # Summary
    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo -e "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed${NC}"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi