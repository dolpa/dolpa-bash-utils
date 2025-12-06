# Bash Utilities Library

A comprehensive collection of utility functions for bash scripts, providing logging, validation, file operations, system detection, and more.

## Features

- **Rich Logging**: Color-coded logging with timestamps and multiple log levels
- **Input Validation**: Functions for validating files, directories, emails, URLs, system names, etc.
- **System Detection**: Auto-detect system information using DMI data
- **File Operations**: Backup creation, directory management, path resolution
- **User Interaction**: Confirmation prompts, progress spinners
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

### File Operations

| Function | Description |
|----------|-------------|
| `create_backup(file, [dir], [name])` | Create timestamped backup |
| `ensure_directory(path, [perms])` | Create directory if missing |
| `get_absolute_path(path)` | Get absolute path |
| `get_script_dir()` | Get calling script's directory |
| `get_script_name()` | Get calling script's name |

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

## String Utilities (strings.sh)

The `strings.sh` module provides a suite of functions for manipulating and analyzing strings and words in bash scripts.

### Features
- Whitespace trimming
- Case conversion (upper/lower/title)
- Substring extraction
- Word counting and selection
- String splitting/joining
- Pattern matching (contains, startswith, endswith)
- String replacement
- Repeating strings

### API Reference
| Function | Description |
|----------|-------------|
| `str_trim(s)` | Remove leading/trailing whitespace |
| `str_upper(s)` | Convert string to upper-case |
| `str_lower(s)` | Convert string to lower-case |
| `str_length(s)` | Get length of string |
| `str_contains(s, pat)` | Test if string contains substring |
| `str_startswith(s, prefix)` | Test if string starts with prefix |
| `str_endswith(s, suffix)` | Test if string ends with suffix |
| `str_replace(s, search, replace)` | Replace all occurrences of search with replace |
| `str_split(s, delim)` | Split string into lines by delimiter |
| `str_join(delim, ...words)` | Join words with delimiter |
| `str_word_count(s)` | Count words in string |
| `str_word_occurrences(s, word)` | Count occurrences of word |
| `str_nth_word(s, n)` | Get the n-th word (1-based) |
| `str_substring(s, offset, [length])` | Get substring from offset (and optional length) |
| `str_repeat(s, n)` | Repeat string n times |
| `str_title(s)` | Convert string to title-case |

### Example Usage
```bash
source "./modules/strings.sh"

trimmed=$(str_trim "   hello world   ")
upper=$(str_upper "abc")
lower=$(str_lower "ABC")
length=$(str_length "hello")
contains=$(str_contains "foo bar" "bar")
joined=$(str_join "," "a" "b" "c")
words=$(str_split "one two three" " ")
title=$(str_title "hello world from bash")
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