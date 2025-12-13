# Tests for Bash Utils Library

This directory contains comprehensive BATS (Bash Automated Testing System) tests for all modules in the Bash Utils Library.

## Test Structure

### Test Files

- **`test_config.bats`** - Tests for the configuration module (`config.sh`)
  - Color support detection
  - Configuration variable initialization
  - Version information
  - Multiple sourcing prevention

- **`test_logging.bats`** - Tests for the logging module (`logging.sh`)
  - All log levels (info, success, warning, error, debug, trace, critical)
  - Log formatting and timestamps
  - Verbose and debug mode behavior
  - Special formatting functions (header, section, step)

- **`test_packages.bats`** - Tests for the package management module (`packages.sh`)
  - Detects the available package manager (via mocked binaries on `$PATH`)
  - Verifies install/update commands are dispatched correctly
  - Validates installed checks for apt and rpm-based managers

- **`test_services.bats`** - Tests for the service management module (`services.sh`)
  - Uses a mock `systemctl` placed first in `$PATH`
  - Service existence and running-state checks
  - Restart and enable command wrappers

- **`test_validation.bats`** - Tests for the validation module (`validation.sh`)
  - Command existence checking
  - File and directory validation
  - Email, URL, and port validation
  - System name validation
  - Permission checking functions

- **`test_files.bats`** - Tests for the file operations module (`files.sh`)
  - File backup creation
  - Directory creation and management
  - Path resolution utilities
  - Script location helpers

- **`test_system.bats`** - Tests for the system detection module (`system.sh`)
  - OS name and version detection
  - Hardware system detection
  - Cross-platform compatibility

- **`test_utils.bats`** - Tests for the utilities module (`utils.sh`)
  - Time and byte formatting
  - Random string generation
  - Version comparison (semver)
  - Retry functionality
  - Signal handling

- **`test_integration.bats`** - Integration tests for the main loader (`bash-utils.sh`)
  - Module loading verification
  - Cross-module functionality
  - Complete library functionality

### Helper Files

- **`test_helper.sh`** - Common test helper functions
  - Temporary file/directory creation
  - Output formatting validation
  - Test environment setup/cleanup

## Running Tests

### Prerequisites

Install BATS testing framework:

```bash
# On Ubuntu/Debian
sudo apt-get install bats

# On macOS with Homebrew
brew install bats-core

# Manual installation
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local

# Or use the test runner's auto-install
./run-tests.sh --install-bats
```

### Using the Test Runner

The main test runner script provides comprehensive testing capabilities:

```bash
# Run all tests
./run-tests.sh

# Run with verbose output
./run-tests.sh --verbose

# List available tests
./run-tests.sh --list

# Run specific test module
./run-tests.sh --test config
./run-tests.sh --test validation

# Run specific test file
./run-tests.sh --test test_logging.bats

# Get help
./run-tests.sh --help
```

### Manual BATS Usage

You can also run BATS directly:

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/test_config.bats

# Run with verbose output
bats --verbose tests/

# Run specific test by name pattern
bats --filter "config" tests/
```

## Test Coverage

### Current Test Coverage

- **Configuration Module**: 8+ tests covering version info, colors, and module loading
- **Logging Module**: 15+ tests covering all log levels and formatting functions
- **Validation Module**: 20+ tests covering all validation functions and edge cases
- **File Operations**: 10+ tests covering backup, directory creation, and path utilities
- **System Detection**: 4+ tests covering OS detection (environment-dependent)
- **Utilities Module**: 15+ tests covering formatting, generation, and utility functions
- **Integration**: 8+ tests covering complete library functionality

### Test Categories

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test module interactions and complete workflows
3. **Edge Case Tests**: Test boundary conditions and error handling
4. **Environment Tests**: Test behavior under different system configurations

## Test Environment

Tests are designed to be:

- **Isolated**: Each test runs independently
- **Reproducible**: Consistent results across runs
- **Cross-platform**: Work on different Unix-like systems
- **Non-destructive**: Don't modify system state
- **Fast**: Complete quickly for rapid development

### Test Configuration

Tests use these environment variables:

- `NO_COLOR=1`: Disable colors for consistent output testing
- `BASH_UTILS_VERBOSE`: Control verbose logging during tests
- `BASH_UTILS_DEBUG`: Control debug logging during tests

### Temporary Resources

Tests that need temporary files or directories:

- Use `mktemp` for temporary file/directory creation
- Clean up resources in `teardown()` functions
- Use test-specific prefixes to avoid conflicts

## Writing New Tests

### Test File Structure

```bash
#!/usr/bin/env bats

# Test [module_name] module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../config.sh"
    source "${BATS_TEST_DIRNAME}/../[module_name].sh"
    
    # Set test environment
    export NO_COLOR=1
    # Other setup...
}

teardown() {
    # Clean up test environment
    unset MODULE_LOADED_FLAG
    # Other cleanup...
}

@test "descriptive test name" {
    # Test implementation
    run function_to_test "arguments"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

### Test Guidelines

1. **Descriptive Names**: Use clear, descriptive test names
2. **Single Responsibility**: Each test should verify one specific behavior
3. **Assertions**: Use appropriate BATS assertions (`run`, `[ ]`, `[[ ]]`)
4. **Error Testing**: Test both success and failure conditions
5. **Cleanup**: Always clean up resources in `teardown()`
6. **Documentation**: Add comments for complex test logic

### Common Test Patterns

```bash
# Test function exists and is callable
@test "function exists" {
    run type function_name
    [ "$status" -eq 0 ]
}

# Test successful function execution
@test "function succeeds with valid input" {
    run function_name "valid_input"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}

# Test function failure
@test "function fails with invalid input" {
    run function_name "invalid_input"
    [ "$status" -eq 1 ]
}

# Test file creation
@test "function creates expected file" {
    run function_that_creates_file
    [ "$status" -eq 0 ]
    [ -f "expected_file" ]
}
```

## Continuous Integration

These tests are designed to work in CI environments:

- No interactive prompts
- Predictable exit codes
- Comprehensive output
- Fast execution
- Minimal dependencies

### CI Configuration Example

```yaml
# GitHub Actions example
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - name: Install BATS
      run: |
        sudo apt-get update
        sudo apt-get install bats
    - name: Run tests
      run: ./run-tests.sh
```

## Troubleshooting

### Common Issues

1. **BATS not found**: Install BATS or use `./run-tests.sh --install-bats`
2. **Permission denied**: Ensure scripts have execute permissions
3. **Module not found**: Check file paths and module dependencies
4. **Color issues**: Tests disable colors with `NO_COLOR=1`
5. **Temporary file conflicts**: Each test should use unique temporary resources

### Debug Mode

Run tests with verbose output for debugging:

```bash
./run-tests.sh --verbose
# or
bats --verbose tests/test_[module].bats
```

### Manual Test Debugging

```bash
# Source modules manually and test functions
source config.sh
source logging.sh
log_info "Test message"
```

Enjoy — and whatever you do, don’t panic! 
Meanwhile, my blog and socials are just sitting there, waiting for attention:
- 🌐 **Blog:** [dolpa.me](https://dolpa.me)
- 📡 **RSS Feed:** [Subscribe via RSS](https://dolpa.me/rss)
- 🐙 **GitHub:** [dolpa on GitHub](https://github.com/dolpa)
- 📘 **Facebook:** [Facebook Page](https://www.facebook.com/dolpa79)
- 🐦 **Twitter (X):** [Twitter Profile](https://x.com/_dolpa)
- 💼 **LinkedIn:** [LinkedIn Profile](https://www.linkedin.com/in/paveldolinin/)
- 👽 **Reddit:** [Reddit Profile](https://www.reddit.com/user/Accomplished_Try_928/)
- 💬 **Telegram:** [Telegram Channel](https://t.me/dolpa_me)
- ▶️ **YouTube:** [YouTube Channel](https://www.youtube.com/c/PavelDolinin)