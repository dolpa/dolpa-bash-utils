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

- **`test_crypto.bats`** - Tests for the crypto utilities module (`crypto.sh`)
  - SHA-256, SHA-1, MD5, SHA-512 checksum generation and verification
  - Base64, URL, and hexadecimal encoding/decoding functions
  - UUID v4 generation and random string generation
  - Secure password generation and entropy calculation
  - File and string encryption/decryption with OpenSSL
  - HMAC signature generation and verification

- **`test_time.bats`** - Tests for the time utilities module (`time.sh`)
  - ISO-8601 and epoch timestamp helpers
  - Epoch formatting/parsing and conversion functions
  - Time arithmetic operations (add/subtract seconds, minutes, hours, days)
  - Duration formatting and parsing utilities
  - Timezone conversion and management functions
  - Date validation and relative time calculations
  - Cron pattern matching and scheduling functions
  - Weekday/weekend detection functions
  - Sleep-until behavior (no-op when already past)

- **`test_validation.bats`** - Tests for the validation module (`validation.sh`)
  - Core validation: command existence, file/directory validation
  - Network validation: IPv4, IPv6, and MAC address format validation
  - Data format validation: dates, phone numbers, JSON format validation
  - Numeric validation: range checking and positive number validation
  - System validation: process checking, disk space validation, username/password strength
  - Email, URL, and port validation functions
  - Environment variable validation
  - Permission checking functions

- **`test_strings.bats`** - Tests for the string processing module (`strings.sh`)
  - Basic string operations: case conversion, trimming, length calculation
  - String search and manipulation: contains, replace, split, join operations
  - Advanced string functions: prefix/suffix removal, padding, reversal
  - String validation: email, URL, numeric, alphanumeric checks
  - Case conversion utilities: snake_case, kebab-case, camelCase conversion
  - URL and HTML encoding/decoding functions
  - Text processing: truncation, word counting, character extraction
  - String comparison and version comparison utilities
  - Random string generation with customizable parameters

- **`test_network.bats`** - Tests for the network utilities module (`network.sh`)
  - Core network functions: ping, hostname resolution, port checking
  - Interface management: local IP enumeration, gateway detection, interface statistics
  - Port scanning and connectivity testing with timeout handling
  - DNS operations: lookup, reverse lookup, MX record retrieval
  - SSL certificate validation and information extraction
  - Network configuration: routing, DNS cache management
  - Bandwidth testing and network usage monitoring
  - Internet connectivity and reachability testing
  - File downloads and URL validation

- **`test_system.bats`** - Tests for the system detection and monitoring module (`system.sh`)
  - OS name/version detection and hardware system detection
  - System architecture and virtualization detection
  - CPU, memory, and disk information retrieval
  - Performance monitoring: CPU usage, memory usage, disk usage
  - System load averages and uptime information
  - System health checks and resource limit validation
  - Process management: process information, service control
  - Resource monitoring and top process listing
  - Cross-platform compatibility testing

- **`test_http.bats`** - Tests for the HTTP client wrapper module (`http.sh`)
  - Core HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
  - Generic HTTP request handling with customizable methods
  - Authentication: Basic auth, Bearer tokens, API key headers
  - File operations: file uploads, multipart form data handling
  - Response processing: header extraction, JSON parsing, status text conversion
  - HTTP utilities: retry logic, success checking, redirect following
  - Status code validation and error handling
  - Mock framework integration for reliable testing
  - Timeout handling and connection testing

- **`test_retry.bats`** - Tests for the retry/backoff module (`retry.sh`)
  - Fixed-attempt retries (`retry_cmd`)
  - Exponential backoff (`retry_with_backoff`)
  - Timeout-based retries (`retry_until`)

- **`test_trap.bats`** - Tests for the signal handling / cleanup module (`trap.sh`)
  - EXIT trap registration (`trap_on_exit`)
  - Signal trap registration (`trap_signals`)
  - Temporary directory helper (`with_tempdir`)

- **`test_packages.bats`** - Tests for the package management module (`packages.sh`)
  - Detects the available package manager (via mocked binaries on `$PATH`)
  - Verifies install/update commands are dispatched correctly
  - Validates installed checks for apt and rpm-based managers

- **`test_services.bats`** - Tests for the service management module (`services.sh`)
  - Uses a mock `systemctl` placed first in `$PATH`
  - Service existence and running-state checks
  - Restart and enable command wrappers

- **`test_files.bats`** - Tests for the file operations module (`files.sh`)
  - File backup creation
  - Directory creation and management
  - Path resolution utilities
  - Script location helpers

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

- **`test_ansi.bats`** - Tests for the ANSI formatting module (`ansi.sh`)
  - Module loading and guard variable verification
  - Color support detection (`ansi_supports_color`)
  - All text color functions with colors disabled and enabled
  - Bright color variants and background color functions
  - Text style functions (bold, dim, italic, underline, blink, reverse, strikethrough)
  - Composite functions (success, error, warning, info, header, code)
  - Utility functions: `ansi_strip`, `ansi_length`, `ansi_reset`, `ansi_test_colors`
  - `NO_COLOR` and `BASH_UTILS_FORCE_COLOR` environment variable handling

- **`test_applications.bats`** - Tests for the application management module (`applications.sh`)
  - Module loading verification
  - `app_is_installed` for existing and non-existing commands
  - `app_install_docker` privilege checks and already-installed detection
  - `app_remove_docker` behaviour when Docker is and isn't installed
  - Package manager detection and install/remove dispatch (mocked)

- **`test_args.bats`** - Tests for the argument parsing module (`args.sh`)
  - Module loading and guard flag verification
  - `args_parse` correctly extracts flags, values, and positional arguments
  - Environment variable fallback for flags (`args_get_flag`)
  - Default value handling for options (`args_get_value`)
  - Usage string storage and retrieval (`args_usage`)

- **`test_env.bats`** - Tests for the environment variable module (`env.sh`)
  - Module loading, flag setting, and multiple-sourcing prevention
  - `env_require` succeeds for set variables, fails for missing ones
  - `env_default` sets defaults without overwriting existing values
  - `env_bool` normalises truthy/falsy values to `true`/`false`
  - `env_from_file` loads well-formed `.env` files, skips comments and blank lines, rejects malformed lines

- **`test_exec.bats`** - Tests for the process execution module (`exec.sh`)
  - Module loading and multiple-sourcing prevention
  - `exec_run` success and failure exit codes
  - `exec_run_capture` capturing stdout and stderr independently
  - `exec_background` launching background jobs and returning PIDs
  - `exec_kill`, `exec_wait`, `exec_wait_result` process control
  - `exec_run_with_timeout` timeout enforcement

- **`test_filesystem.bats`** - Tests for the filesystem operations module (`filesystem.sh`)
  - Module loading and guard variable verification
  - Temporary file and directory creation (`create_temp_file`, `create_temp_dir`)
  - File metadata retrieval: size, modification time, permissions, owner, group
  - Path type detection (`is_path_file`, `is_path_directory`, `is_path_symlink`, etc.)
  - File operations: copy, move, delete, touch, write, append, truncate, symlink, hardlink
  - Permission operations: `chmod_file`, `chown_file`, `chgrp_file`
  - Directory listing and recursive file finding

- **`test_prompts.bats`** - Tests for the interactive prompts module (`prompts.sh`)
  - Module loading and guard flag verification
  - `prompt_input` with typed value, default value, and whitespace trimming
  - `prompt_password` hidden input handling
  - `prompt_confirm` and `prompt_confirm_yes` yes/no handling
  - `prompt_menu` selection with mock input
  - `prompt_number` numeric input and range validation
  - `prompt_pause` wait-for-enter behaviour

- **`test_sysctl_install.bats`** - Integration tests for the dolpa-sysctl `install.sh` script
  - Profile listing includes expected system names (supports legacy filename typo)
  - Dry-run install does not require root privileges
  - Auto-detection can be overridden via `SYSCTL_SYSTEM_NAME` environment variable
  - `detect` command prints a profile name or fails clearly
  - Skipped automatically when `dolpa-sysctl` repo is not present

- **`test_system-mount.bats`** - Tests for the system mount module (`system-mount.sh`)
  - Module loading, flag setting, and multiple-sourcing prevention
  - `is_mounted` returns success for `/` and failure for non-mount paths
  - `get_mount_point` resolves paths to their mount point
  - `mount_tmpfs` and `unmount_path` fail gracefully without root
  - Base directory configuration (`mount_set_base_dir`, `mount_get_base_dir`)
  - Verbose and dry-run mode flags
  - CLI helpers (`mount_cli_mount`, `mount_cli_umount`, `mount_cli_status`, `mount_cli_list`)

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

**542 tests across 25 modules**

| Module | File | Tests |
|--------|------|------:|
| ANSI Formatting | `test_ansi.bats` | 42 |
| Application Management | `test_applications.bats` | 17 |
| Argument Parsing | `test_args.bats` | 6 |
| Configuration | `test_config.bats` | 9 |
| Cryptography | `test_crypto.bats` | 28 |
| Environment Variables | `test_env.bats` | 15 |
| Process Execution | `test_exec.bats` | 13 |
| File Operations | `test_files.bats` | 13 |
| Filesystem Utilities | `test_filesystem.bats` | 44 |
| HTTP Client | `test_http.bats` | 36 |
| Integration | `test_integration.bats` | 9 |
| Logging | `test_logging.bats` | 21 |
| Network Utilities | `test_network.bats` | 33 |
| Package Management | `test_packages.bats` | 12 |
| Interactive Prompts | `test_prompts.bats` | 17 |
| Retry / Backoff | `test_retry.bats` | 8 |
| Service Management | `test_services.bats` | 8 |
| String Processing | `test_strings.bats` | 65 |
| Sysctl Install (integration) | `test_sysctl_install.bats` | 4 |
| System Mount | `test_system-mount.bats` | 10 |
| System Detection | `test_system.bats` | 34 |
| Time Utilities | `test_time.bats` | 37 |
| Signal / Trap Handling | `test_trap.bats` | 5 |
| Utilities | `test_utils.bats` | 12 |
| Validation | `test_validation.bats` | 44 |

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