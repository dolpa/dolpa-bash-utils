### Argument Parsing (args.sh)

The `args.sh` module provides robust command-line argument parsing for bash scripts, supporting flags, options with values, positional arguments, and grouped short flags.

#### Features
- Register known flags and value options
- Parse long options (`--flag`, `--option=value`)
- Parse short flag groups (`-abc`)
- Retrieve flags, option values, and positionals
- Fallback to environment variables
- Usage string helper

#### API Reference
| Function | Description |
|----------|-------------|
| `args_set_flags <flag>...` | Register boolean flags (e.g. `--force`) |
| `args_set_values <option>...` | Register options that expect a value (e.g. `--output <file>`) |
| `args_set_usage <string>` | Set a usage/help string |
| `args_usage` | Print the usage string |
| `args_parse <argv...>` | Parse command-line arguments |
| `args_get_flag <flag> [fallback]` | Check if a flag is set (returns 0 if set) |
| `args_get_value <option> [default]` | Get the value for an option, or a default |
| `args_get_positional <index>` | Get the N-th positional argument (0-based) |

#### Example Usage
```bash
source modules/args.sh
args_set_flags --force --dry-run
args_set_values --output --input
args_set_usage "--input <file> --output <file> [--force] [--dry-run]"
args_parse "$@"

if args_get_flag --force; then
    echo "Force mode enabled"
fi
outfile=$(args_get_value --output "default.txt")
first_arg=$(args_get_positional 0)
args_usage
```
# Bash Utilities Library

A comprehensive collection of utility functions for bash scripts, providing logging, validation, file operations, system detection, and more.

## Files layout:
```
bash-utils/
├── Dockerfile
├── LICENSE
├── README.md
├── bash-utils.sh
├── modules/
│   ├── applications.sh
│   ├── args.sh
│   ├── config.sh
│   ├── env.sh
│   ├── exec.sh
│   ├── files.sh
│   ├── filesystem.sh
│   ├── logging.sh
│   ├── network.sh
│   ├── packages.sh
│   ├── prompts.sh
│   ├── services.sh
│   ├── strings.sh
│   ├── system.sh
│   ├── utils.sh
│   └── validation.sh
├── run-tests-docker.sh
├── run-tests.sh
├── tests/
│   ├── README.md
│   ├── test_applications.bats
│   ├── test_args.bats
│   ├── test_config.bats
│   ├── test_env.bats
│   ├── test_exec.bats
│   ├── test_files.bats
│   ├── test_filesystem.bats
│   ├── test_helper.sh
│   ├── test_integration.bats
│   ├── test_logging.bats
│   ├── test_network.bats
│   ├── test_packages.bats
│   ├── test_prompts.bats
│   ├── test_services.bats
│   ├── test_strings.bats
│   ├── test_system.bats
│   ├── test_utils.bats
│   └── test_validation.bats
```

## Features

- **Rich Logging**: Color-coded logging with timestamps and multiple log levels
- **Input Validation**: Functions for validating files, directories, emails, URLs, system names, etc.
- **System Detection**: Auto-detect system information using DMI data
- **File Operations**: Backup creation, directory management, path resolution
- **FileSystem Operations**: Comprehensive file‑system operations including file manipulation, permissions, symlinks, and path analysis
- **Network Operations**: Network utilities including ping, hostname resolution, port checking, file downloads, and URL validation
- **Package Management**: A small abstraction over common Linux package managers (install/update/installed checks)
- **Process Execution**: Background process management, command execution with capture, timeout handling, and process monitoring
- **Application Management**: Install, remove, and manage applications across different Linux distributions (Docker support included)
- **String Manipulation**: Comprehensive string processing utilities including case conversion, trimming, and validation
- **User Interaction**: Interactive prompts, confirmations, password input, and menu selections
- **Utility Functions**: Retry logic, human-readable formatting, random string generation
- **Signal Handling**: Graceful script termination and cleanup
- **Color Support**: Comprehensive color definitions with automatic detection

## Installation

### As a Submodule

```bash
# Add as a git submodule
git submodule add https://github.com/dolpa/bash-utils.git lib/bash-utils

# Initialize and update
git submodule update --init --recursive
```

### Direct Download

```bash
# Download the script
curl -o lib/bash-utils.sh https://raw.githubusercontent.com/dolpa/bash-utils/main/bash-utils.sh

# Make it executable
chmod +x lib/bash-utils.sh
```

## Usage

### Basic Usage

```bash
#!/bin/bash

# Source the utility library
source "$(dirname "${BASH_SOURCE[0]}")/lib/bash-utils.sh"

# Enable verbose logging
BASH_UTILS_VERBOSE=true

# Use logging functions
log_info "Starting application"
log_success "Operation completed successfully"
log_warning "This is a warning"
log_error "An error occurred"

# Check privileges
if check_privileges "This operation requires root access"; then
    log_info "Running with sufficient privileges"
fi

# Validate inputs
if validate_file "/etc/passwd" "System password file"; then
    log_info "Password file exists"
fi

# Create backups
backup_file=$(create_backup "/etc/hosts" "/tmp/backups")
log_info "Backup created: $backup_file"

# Auto-detect system
if system_name=$(auto_detect_system); then
    log_info "Detected system: $system_name"
fi
```

### Advanced Features

```bash
#!/bin/bash
source lib/bash-utils.sh

# Set up signal handlers
setup_signal_handlers

# Use confirmation prompts
if confirm "Do you want to continue?" "y"; then
    log_info "User confirmed"
fi

# Retry operations with exponential backoff
retry 3 2 30 curl -f "https://example.com/api"

# Show progress spinner
long_running_command &
show_spinner $! "Processing data..."

# Format human-readable output
log_info "File size: $(bytes_to_human 1536)"
log_info "Duration: $(seconds_to_human 3661)"
```

## Configuration

The library can be configured using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `BASH_UTILS_VERBOSE` | `false` | Enable verbose/debug logging |
| `BASH_UTILS_DEBUG` | `false` | Enable trace-level logging |
| `BASH_UTILS_TIMESTAMP_FORMAT` | `'%Y-%m-%d %H:%M:%S'` | Timestamp format for logs |
| `BASH_UTILS_LOG_LEVEL` | `"INFO"` | Minimum log level |
| `NO_COLOR` | - | Disable color output if set to `1` |

## API Reference

### Logging Functions

| Function | Description |
|----------|-------------|
| `log_trace(message...)` | Trace-level logging (debug mode only) |
| `log_debug(message...)` | Debug-level logging (verbose mode) |
| `log_info(message...)` | Informational messages |
| `log_success(message...)` | Success messages (green) |
| `log_warning(message...)` | Warning messages (yellow) |
| `log_error(message...)` | Error messages (red, to stderr) |
| `log_critical(message...)` | Critical errors (red background) |
| `log_header(message...)` | Section headers with borders |
| `log_section(message...)` | Subsection headers |
| `log_step(number, message)` | Numbered step indicators |

### Validation Functions

| Function | Description |
|----------|-------------|
| `command_exists(cmd)` | Check if command is available |
| `is_root()` | Check if running as root |
| `is_sudo()` | Check if running with sudo |
| `check_privileges([message])` | Ensure root/sudo access |
| `validate_file(path, [desc])` | Validate file existence |
| `validate_directory(path, [desc])` | Validate directory existence |
| `validate_not_empty(var, [name])` | Check variable is not empty |
| `validate_system_name(name)` | Validate system name format |
| `validate_email(email)` | Validate email format |
| `validate_url(url)` | Validate URL format |
| `validate_port(port)` | Validate port number (1-65535) |

## File Operations

### Public functions

| Function | Description |
|----------|-------------|
| `create_backup(file, [dir], [name])` | Create timestamped backup |
| `ensure_directory(path, [perms])` | Create directory if missing |
| `get_absolute_path(path)` | Get absolute path |
| `get_script_dir()` | Get calling script's directory |
| `get_script_name()` | Get calling script's name |

## 📁 filesystem.sh – File‑system utilities

The `filesystem.sh` module bundles a small set of safe, POSIX‑compatible helpers for dealing with files, directories and permissions. It is loaded automatically by `bash-utils.sh` when you source the library.

### Public functions

| Function | Description |
|----------|-------------|
| `fs_exists <path>` | Returns true if *any* file‑system object exists at `<path>`. |
| `fs_is_file <path>` | True only for regular files. |
| `fs_is_dir <path>` | True only for directories. |
| `fs_is_symlink <path>` | Detects symbolic links. |
| `fs_create_dir <path> [mode]` | Recursively creates a directory tree, optionally setting its mode (default `0755`). |
| `fs_remove <path> [force]` | Deletes a file or directory; `force=true` uses `rm -rf`. |
| `fs_copy <src> <dst> [preserve]` | Copies a file or directory; `preserve=true` keeps timestamps/ownership. |
| `fs_move <src> <dst>` | Moves/renames a file or directory. |
| `fs_perm_get <path>` | Prints the octal permission bits of `<path>`. |
| `fs_perm_set <path> <mode>` | Sets the permission bits of `<path>` (e.g. `0644`). |

## Application Management (applications.sh)

*Documentation for applications.sh module. See above for details.*

## Argument Parsing (args.sh)

*Documentation for args.sh module. See above for details.*

## Configuration (config.sh)

*Documentation for config.sh module. Add details about configuration helpers, variables, and usage.*

## Environment Helpers (env.sh)

*Documentation for env.sh module. Add details about environment variable helpers and usage.*

## Process Execution (exec.sh)

*Documentation for exec.sh module. See above for details.*

## File Operations (files.sh)

*Documentation for files.sh module. Add details about file operation helpers and usage.*

## Filesystem Operations (filesystem.sh)

The `filesystem.sh` module provides comprehensive file and directory management utilities with proper error handling and logging.

### Core Functions

| Function | Description |
|----------|-------------|
| `create_temp_file()` | Create a temporary file and return its path |
| `create_temp_dir()` | Create a temporary directory and return its path |
| `get_file_size(path)` | Get file size in bytes |
| `get_file_mod_time(path)` | Get file modification timestamp |
| `get_file_perm(path)` | Get file permissions in octal format |
| `get_file_owner(path)` | Get file owner name |
| `get_file_group(path)` | Get file group name |
| `copy_file(src, dest)` | Copy a file |
| `move_file(src, dest)` | Move/rename a file |
| `delete_file(path)` | Delete a file |
| `delete_directory(path)` | Delete a directory |
| `touch_file(path)` | Create or update file timestamp |
| `write_file(path, content)` | Write content to file |
| `append_to_file(path, content)` | Append content to file |
| `truncate_file(path)` | Truncate file to zero length |
| `chmod_file(path, mode)` | Change file permissions |
| `chown_file(path, owner)` | Change file owner |
| `chgrp_file(path, group)` | Change file group |
| `symlink_file(target, link)` | Create symbolic link |
| `hardlink_file(target, link)` | Create hard link |
| `readlink_path(path)` | Read symbolic link target |

### Path Analysis

| Function | Description |
|----------|-------------|
| `get_file_extension(path)` | Extract file extension |
| `get_filename_without_extension(path)` | Get filename without extension |
| `get_basename(path)` | Get basename of path |
| `get_dirname(path)` | Get directory name of path |
| `get_absolute_path(path)` | Convert to absolute path |
| `get_canonical_path(path)` | Get canonical path (resolve symlinks) |

### Path Type Predicates

| Function | Description |
|----------|-------------|
| `is_path_writable(path)` | Check if path is writable |
| `is_path_readable(path)` | Check if path is readable |
| `is_path_executable(path)` | Check if path is executable |
| `is_path_hidden(path)` | Check if path is hidden (starts with .) |
| `is_path_symlink(path)` | Check if path is a symbolic link |
| `is_path_directory(path)` | Check if path is a directory |
| `is_path_file(path)` | Check if path is a regular file |
| `is_path_fifo(path)` | Check if path is a FIFO |
| `is_path_socket(path)` | Check if path is a socket |
| `is_path_block(path)` | Check if path is a block device |
| `is_path_char(path)` | Check if path is a character device |
| `is_path_empty(path)` | Check if file exists and has zero size |
| `is_path_nonempty(path)` | Check if file exists and has size > 0 |

### Example Usage
```bash
source "./modules/filesystem.sh"

# Create temporary files
temp_file=$(create_temp_file)
temp_dir=$(create_temp_dir)

# File operations
chmod_file "$temp_file" 644
chown_file "$temp_file" "$(whoami)"
write_file "$temp_file" "Hello World"

# Path analysis
if is_path_file "$temp_file"; then
    size=$(get_file_size "$temp_file")
    perm=$(get_file_perm "$temp_file")
    echo "File size: $size bytes, permissions: $perm"
fi

# Cleanup
delete_file "$temp_file"
delete_directory "$temp_dir"
```

## Process Execution (exec.sh)

The `exec.sh` module provides utilities for running commands, managing background processes, and handling process execution with timeouts and capture capabilities.

### Core Functions

| Function | Description |
|----------|-------------|
| `exec_run(cmd...)` | Execute command and return exit status |
| `exec_run_capture(out_var, err_var, cmd...)` | Execute command and capture stdout/stderr in variables |
| `exec_background(cmd...)` | Start command in background and return PID |
| `exec_is_running(pid)` | Check if process is still running |
| `exec_kill(pid, [signal])` | Send signal to process (default: TERM) |
| `exec_wait(pid, [timeout])` | Wait for process to finish with optional timeout |
| `exec_run_with_timeout(timeout, cmd...)` | Run command with timeout (kills if exceeds) |

### Example Usage
```bash
source "./modules/exec.sh"

# Basic command execution
exec_run ls -la /tmp
echo "Command exited with status: $?"

# Capture output
stdout=""
stderr=""
exec_run_capture stdout stderr ls /nonexistent
echo "STDOUT: $stdout"
echo "STDERR: $stderr"

# Background process management
pid=$(exec_background sleep 30)
echo "Started background process: $pid"

if exec_is_running "$pid"; then
    echo "Process is running"
    exec_kill "$pid"
fi

# Wait with timeout
pid=$(exec_background sleep 5)
if exec_wait "$pid" 10; then
    echo "Process finished within timeout"
else
    echo "Process timed out"
    exec_kill "$pid"
fi

# Run with timeout
if exec_run_with_timeout 5 curl "https://example.com"; then
    echo "Command completed within timeout"
else
    echo "Command timed out or failed"
fi
```

## Logging (logging.sh)

*Documentation for logging.sh module. Add details about logging functions, log levels, and usage.*

## Network Operations (network.sh)

The `network.sh` module provides utilities for network operations including connectivity testing, hostname resolution, port checking, file downloads, and URL validation.

### Core Functions

| Function | Description |
|----------|-------------|
| `ping_host(host, [count])` | Ping a remote host using system ping binary |
| `resolve_ip(hostname)` | Resolve a hostname to an IP address |
| `is_port_open(host, port)` | Test whether a TCP port is open using netcat |
| `download_file(url, dest)` | Download a remote file to local destination |
| `check_url(url)` | Perform HEAD request to verify URL is reachable |
| `get_public_ip()` | Retrieve the public IP address of current machine |

### Configuration

| Variable | Description | Default |
|----------|-------------|----------|
| `BASH_UTILS_NETWORK_TIMEOUT` | Timeout for network operations (seconds) | `5` |

### Example Usage
```bash
source "./modules/network.sh"

# Test connectivity
if ping_host "google.com"; then
    echo "Internet connection available"
fi

# Resolve hostname
ip=$(resolve_ip "github.com")
echo "GitHub IP: $ip"

# Check if port is open
if is_port_open "github.com" 443; then
    echo "HTTPS port is open"
fi

# Download file
if download_file "https://example.com/file.txt" "/tmp/download.txt"; then
    echo "File downloaded successfully"
fi

# Verify URL is reachable
if check_url "https://api.github.com"; then
    echo "API endpoint is accessible"
fi

# Get public IP
public_ip=$(get_public_ip)
echo "Your public IP: $public_ip"
```

### Dependencies

This module relies on a few internal helpers from the utils library:

- **`config.sh`** – Provides colour settings and verbosity flags used throughout the module.
- **`logging.sh`** – All filesystem-related actions are recorded using `log_info` and `log_error`.
- **`validation.sh`** – Supplies internal validation functions such as `validate_file` and `validate_directory`, used to ensure safe and predictable behaviour.

### System Detection

| Function | Description |
|----------|-------------|
| `get_os_name()` | Get operating system name |
| `get_os_version()` | Get operating system version |
| `auto_detect_system()` | Auto-detect system type from DMI |

### Utility Functions

| Function | Description |
|----------|-------------|
| `show_spinner(pid, [message])` | Show spinner while process runs |
| `confirm(message, [default])` | Interactive confirmation prompt |
| `retry(attempts, delay, max_delay, cmd...)` | Retry with exponential backoff |
| `seconds_to_human(seconds)` | Format duration (e.g., "1h 30m 45s") |
| `bytes_to_human(bytes)` | Format file size (e.g., "1.5GB") |
| `generate_random_string([length], [chars])` | Generate random string |
| `is_semver(version)` | Check if valid semantic version |
| `compare_versions(v1, v2)` | Compare semantic versions (-1, 0, 1) |

### Signal Handling

| Function | Description |
|----------|-------------|
| `setup_signal_handlers([cleanup_func])` | Set up EXIT, INT, TERM handlers |
| `cleanup_on_exit()` | Default cleanup function |





### Example usage

```bash
#!/usr/bin/env bash
source "./bash-utils.sh"   # pulls in all modules, including filesystem

# Create a safe workspace
WORKDIR=$(mktemp -d)
fs_create_dir "$WORKDIR/logs" 0750

# Copy a configuration file, preserving its attributes
fs_copy "/etc/myapp.conf" "$WORKDIR/conf/myapp.conf" true

# Verify that the copy succeeded
if fs_is_file "$WORKDIR/conf/myapp.conf"; then
  log_info "Configuration successfully staged."
else
  log_error "Failed to copy configuration."
  exit 1
fi

# Clean up on exit
cleanup_on_exit() { rm -rf "$WORKDIR"; }
setup_signal_handlers   # from utils.sh – ensures the cleanup runs on SIGINT/SIGTERM

## Application Management (applications.sh)

The `applications.sh` module provides utilities for installing, removing, and managing applications across different Linux distributions. Currently supports Docker Engine with plans for additional applications.

### Core Functions

| Function | Description |
|----------|-------------|
| `app_is_installed(app)` | Check if an application is installed and available |
| `app_install_docker()` | Install Docker Engine on supported Linux distributions |
| `app_remove_docker()` | Remove Docker Engine and related components |

### Supported Distributions

| Distribution | Package Manager | Docker Support |
|--------------|----------------|----------------|
| Ubuntu/Debian | APT | ✓ |
| RHEL/CentOS/Fedora | DNF/YUM | ✓ |
| Arch Linux | Pacman | Planned |
| openSUSE | Zypper | Planned |

### Example Usage
```bash
source "./modules/applications.sh"

# Check if an application is installed
if app_is_installed "docker"; then
    echo "Docker is already installed"
else
    echo "Docker is not installed"
fi

# Install Docker (requires root privileges)
if app_install_docker; then
    echo "Docker installation completed successfully"
    echo "Please log out and log back in for group changes to take effect"
else
    echo "Docker installation failed"
fi

# Remove Docker (requires root privileges)
if app_remove_docker; then
    echo "Docker removed successfully"
else
    echo "Docker removal failed"
fi

# Verify installation
if app_is_installed "docker"; then
    docker --version
    systemctl status docker
fi
```

### Docker Installation Process

The `app_install_docker()` function performs these steps:

1. **Prerequisites Check**: Verifies root privileges and OS compatibility
2. **Conflict Removal**: Removes conflicting packages (docker.io, podman-docker, etc.)
3. **Repository Setup**: Adds Docker's official repository with GPG key verification
4. **Package Installation**: Installs Docker CE, CLI, containerd, and plugins
5. **Service Configuration**: Enables and starts Docker service
6. **User Configuration**: Adds current user to docker group
7. **Verification**: Confirms installation success

### Dependencies

This module relies on several library components:

- **`config.sh`** – Provides color settings and configuration constants
- **`logging.sh`** – All operations are logged with appropriate levels
- **`validation.sh`** – Input validation and system checking functions
- **`system.sh`** – OS detection and system information gathering
- **`utils.sh`** – Utility functions like command_exists and is_root
- **`exec.sh`** – Command execution with proper error handling
- **`network.sh`** – File downloads and connectivity verification

### Colors

The library provides comprehensive color support with automatic terminal detection:

```bash
# Standard colors
COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, COLOR_PURPLE, COLOR_CYAN

# Bright colors
COLOR_BRIGHT_RED, COLOR_BRIGHT_GREEN, etc.

# Background colors
COLOR_BG_RED, COLOR_BG_GREEN, etc.

# Text formatting
COLOR_BOLD, COLOR_DIM, COLOR_UNDERLINE, COLOR_REVERSE

# Reset
COLOR_RESET, COLOR_NC (No Color)

# Legacy aliases
RED, GREEN, YELLOW, BLUE, NC
```
declare -a words

## Package Management (packages.sh)

The `packages.sh` module provides a small, consistent API for interacting with common Linux package managers. It detects the available manager and exposes helpers to update repositories, install packages, and check whether a package is installed.

### API Reference

| Function | Description |
|----------|-------------|
| `pkg_detect_manager` | Detects the package manager and sets `PKG_MANAGER` |
| `pkg_update` | Updates package repositories/metadata |
| `pkg_install <pkg>...` | Installs one or more packages |
| `pkg_installed <pkg>` | Returns 0 if the package is installed, otherwise 1 |

### Example Usage

```bash
source "./modules/packages.sh"

pkg_update
pkg_install curl git

if pkg_installed git; then
    echo "git is installed"
fi
```

## User Interaction (prompts.sh)

The `prompts.sh` module provides interactive functions for user input, confirmations, and menu selections.

### Features
- Text input with optional defaults
- Secure password input (no echo)
- Yes/No confirmation prompts
- Numbered menu selections
- Numeric input with validation
- Pause/continue prompts

### API Reference

| Function | Description |
|----------|-------------|
| `prompt_input(message, [default])` | Prompt for text input with optional default |
| `prompt_password(message)` | Prompt for password (silent input) |
| `prompt_confirm(message)` | Yes/No confirmation (default: No) |
| `prompt_confirm_yes(message)` | Yes/No confirmation (default: Yes) |
| `prompt_menu(title, option1, option2, ...)` | Display numbered menu and get selection |
| `prompt_pause([message])` | Wait for Enter key press |
| `prompt_number(message, [min], [max])` | Prompt for numeric input with validation |

### Example Usage
```bash
source "./modules/prompts.sh"

# Basic input
name=$(prompt_input "Enter your name: " "Anonymous")
password=$(prompt_password "Enter password: ")

# Confirmations
if prompt_confirm "Delete all files?"; then
    echo "Deleting files..."
fi

if prompt_confirm_yes "Continue with installation?"; then
    echo "Installing..."
fi

# Menu selection
choice=$(prompt_menu "Select action:" "Create file" "Delete file" "Edit file")
echo "You selected: $choice"

# Numeric input
age=$(prompt_number "Enter age: " 1 120)
echo "Age: $age"

# Pause
prompt_pause "Press Enter to continue..."
```

## Service Management (services.sh)

The `services.sh` module provides a small, consistent API for interacting with services.
On systemd-based Linux distributions it uses `systemctl`; when systemd is not available it falls back to the legacy `service` command if present.

### API Reference

| Function | Description |
|----------|-------------|
| `service_exists <name>` | Returns 0 if the unit/service exists, otherwise 1 |
| `service_running <name>` | Returns 0 if the service is running/active, otherwise 1 |
| `service_restart <name>` | Restarts the service; returns the underlying command status |
| `service_enable <name>` | Enables the service at boot; returns the underlying command status |

### Example Usage

```bash
source "./modules/services.sh"

if service_exists docker; then
    if service_running docker; then
        echo "docker is running"
    else
        echo "docker is not running; restarting"
        service_restart docker
    fi

    # Enable on boot (systemd; SysV requires chkconfig)
    service_enable docker
fi
```

## String Utilities (strings.sh)

The `strings.sh` module provides comprehensive string manipulation and text processing utilities.

### Features
- Case conversion (upper/lower/title)
- Whitespace trimming (left, right, both)
- String validation and testing (contains, starts/ends with, empty check)
- String manipulation (replace, substring, reverse)
- String formatting (padding, repeating)
- Array operations (split, join)

### API Reference

| Function | Description |
|----------|-------------|
| `str_upper(string)` | Convert string to uppercase |
| `str_lower(string)` | Convert string to lowercase |
| `str_title(string)` | Convert string to title case |
| `str_length(string)` | Get string length in characters |
| `str_trim(string)` | Remove leading and trailing whitespace |
| `str_ltrim(string)` | Remove leading whitespace only |
| `str_rtrim(string)` | Remove trailing whitespace only |
| `str_starts_with(string, prefix)` | Check if string starts with prefix |
| `str_ends_with(string, suffix)` | Check if string ends with suffix |
| `str_contains(string, substring)` | Check if string contains substring |
| `str_replace(string, search, replace)` | Replace all occurrences |
| `str_replace_first(string, search, replace)` | Replace first occurrence only |
| `str_split(string, delimiter, array_name)` | Split string into array |
| `str_join(delimiter, word1, word2, ...)` | Join words with delimiter |
| `str_repeat(string, count)` | Repeat string n times |
| `str_pad_left(string, length, [char])` | Pad string on the left |
| `str_pad_right(string, length, [char])` | Pad string on the right |
| `str_is_empty(string)` | Check if string is empty/whitespace |
| `str_substring(string, start, [length])` | Extract substring |
| `str_reverse(string)` | Reverse a string |

### Example Usage
```bash
source "./modules/strings.sh"

# Case conversion
upper=$(str_upper "hello world")              # "HELLO WORLD"
lower=$(str_lower "HELLO WORLD")              # "hello world"
title=$(str_title "hello world")              # "Hello World"

# String testing
if str_contains "hello world" "world"; then
        echo "Found 'world' in string"
fi

# String manipulation
trimmed=$(str_trim "   hello   ")             # "hello"
replaced=$(str_replace "foo bar foo" "foo" "baz")  # "baz bar baz"

# Array operations
declare -a words
str_split "a,b,c" "," words
joined=$(str_join "-" "${words[@]}")          # "a-b-c"
```

## Examples

### Script Template

```bash
#!/bin/bash

# Script configuration
set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/bash-utils.sh"

# Configuration
BASH_UTILS_VERBOSE=false

# Set up signal handlers
setup_signal_handlers

# Main function
main() {
    log_header "My Application v1.0"
    
    # Check prerequisites
    check_privileges "This script requires root access"
    
    if ! command_exists "curl"; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    # Validate inputs
    local config_file="$1"
    validate_file "$config_file" "Configuration file"
    
    # Create backup
    local backup=$(create_backup "$config_file")
    log_info "Created backup: $backup"
    
    # Process with confirmation
    if confirm "Process configuration file?" "y"; then
        process_config "$config_file"
        log_success "Configuration processed successfully"
    else
        log_info "Operation cancelled by user"
    fi
}

process_config() {
    local config="$1"
    
    log_step 1 "Reading configuration"
    # ... processing logic ...
    
    log_step 2 "Applying changes"
    # ... more processing ...
    
    log_success "All steps completed"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Testing

The library includes self-testing capabilities:

```bash
# Show library information
bash lib/bash-utils.sh

# Test individual functions
source lib/bash-utils.sh
bash_utils_info
```

## Running tests in Docker

You can run the full test suite in an isolated Docker container using the provided `Dockerfile`.

### Build the Docker image

From the repository root, build the image:

```bash
docker build -t bash-utils .
```

### Run the tests in the container

Run the container (it will execute `run-tests.sh` and exit with the test result):

```bash
docker run -ti --rm bash-utils
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all existing tests pass
5. Submit a pull request

## License

Unlicense - see LICENSE file for details.

## Changelog


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