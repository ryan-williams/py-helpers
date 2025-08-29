# Python Venv System Tests

This directory contains tests for the Python virtual environment management system.

## Test Suite

### `test-venv-system.sh`

Comprehensive test suite for the new Python venv structure that avoids nested symlinks.

#### Running the Tests

```bash
cd ~/.rc/py/tests
./test-venv-system.sh
```

The test suite will:
- Create temporary test directories in `$TMPDIR` (or `/tmp`)
- Run 26 tests covering all aspects of the venv system
- Automatically clean up all test artifacts

#### Test Coverage

The test suite validates:

1. **Basic venv creation**
   - Verifies `.venv/X.Y.Z/` directory structure
   - Checks direct symlinks are created correctly
   - Validates `.venv/current` file is created

2. **Multiple Python versions**
   - Tests creating multiple versions side-by-side
   - Verifies current version tracking
   - Tests version switching functionality

3. **No nested symlinks**
   - Ensures `.venv/bin` points directly to version directory
   - Verifies no intermediate `.venv/cur` symlink exists
   - Validates this fixes the Python 3.11 nested symlink issue

4. **Environment type detection**
   - Tests detection of `uv` from `uv.lock` file
   - Tests detection of `conda` from `environment.yml`
   - Validates explicit `.python-env` declarations
   - Verifies default fallback to `venv` type

5. **Partial version switching**
   - Tests switching with full version (e.g., 3.11.13)
   - Tests switching with partial version (e.g., 3.11)
   - Validates version matching logic

6. **Symlink structure validation**
   - Verifies all symlinks (bin, lib, include, pyvenv.cfg) point correctly
   - Ensures consistency across all symlinks

7. **PATH resolution**
   - Tests `.venv/bin/python` is accessible through PATH
   - Validates Python resolves correctly when invoked

8. **Real Python execution** (when `uv` is available)
   - Tests actual Python execution through symlinks
   - Validates `sys.prefix` resolution
   - Validates `sys.executable` resolution

#### Expected Output

A successful test run shows:
```
=========================================
Test Summary
=========================================
Tests run: 26
Passed: 26
Failed: 0

All tests passed!
```

#### Test Implementation Details

The test suite uses:
- Mock functions for testing without full dependencies
- Real venv creation when `uv` is available
- Comprehensive assertions for structure validation
- Proper cleanup using trap handlers

#### Directory Structure Being Tested

The tests validate this structure:
```
.venv/
  3.11.13/               # Full venv created by uv
  3.12.11/               # Another version
  bin -> 3.12.11/bin     # Direct symlink to current version's bin
  lib -> 3.12.11/lib     # Direct symlink to current version's lib
  include -> 3.12.11/include
  pyvenv.cfg -> 3.12.11/pyvenv.cfg
  current                # Text file containing current version
```

This structure avoids the problematic nested symlinks that would look like:
```
.venv/bin -> cur/bin -> 3.12.11/bin  # BAD - breaks Python 3.11
```

## Adding New Tests

To add new tests to the suite:

1. Create a new test function following the naming pattern `test_<feature>()`
2. Use the provided assertion functions:
   - `assert_equals` - Check values match
   - `assert_exists` - Check file/directory exists
   - `assert_not_exists` - Check file/directory doesn't exist
   - `assert_symlink` - Check symlink target
3. Update test counters using `TESTS_RUN`, `TESTS_PASSED`, `TESTS_FAILED`
4. Add the function call to the `main()` function

## Test Utilities

The test suite provides these utilities:

- **Color output** - Green for pass, red for fail, yellow for warnings
- **Automatic cleanup** - Removes all test artifacts on exit
- **Mock functions** - Simulates venv creation without full dependencies
- **Flexible paths** - Uses `$TMPDIR` or `/tmp` for test directories

## Related Files

The tests validate functionality implemented in:
- `../venv-helpers.sh` - Main venv management functions
- `../python-env-type.sh` - Environment type detection
- `../py-direnv-rc.sh` - direnv integration
- `../.py-rc` - Python configuration