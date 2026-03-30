# Bash Utilities Library

![Badge Status](https://img.shields.io/badge/status-stable-brightgreen.svg)
![Language](https://img.shields.io/badge/language-bash-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)

A comprehensive collection of utility functions for bash scripts, providing logging, validation, file operations, system detection, ANSI formatting, and more.

## 📋 Table of Contents

- [🏗️ Project Structure](#️-project-structure)
- [✨ Key Features](#-key-features)
- [⚡ Quick Start](#-quick-start)
- [📦 Installation](#-installation)
- [🔧 Usage](#-usage)
- [📚 Module Reference](#-module-reference)
- [🧪 Testing](#-testing)
- [📖 Examples](#-examples)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

## 🏗️ Project Structure

```
bash-utils/
├── 📄 README.md               # Project documentation
├── 📄 LICENSE                 # MIT license
├── 📄 Dockerfile              # Container build configuration
├── 🚀 bash-utils.sh           # Main library loader
├── 🚀 run-tests.sh            # Test runner
├── 🚀 run-tests-docker.sh     # Docker test runner
├── 📂 modules/                # Core utility modules
│   ├── 🎨 ansi.sh             # ANSI colors and terminal formatting
│   ├── 🚀 applications.sh     # Application management (Docker, etc.)
│   ├── 🎯 args.sh             # Command-line argument parsing
│   ├── ⚙️ config.sh           # Configuration management
│   ├── 🔐 crypto.sh           # Cryptographic utilities
│   ├── 🌍 env.sh              # Environment variable handling
│   ├── ⚡ exec.sh              # Process execution and management
│   ├── 📁 files.sh            # File manipulation utilities
│   ├── 🗃️ filesystem.sh       # File system operations
│   ├── 📝 logging.sh          # Comprehensive logging system
│   ├── 🌐 network.sh          # Network operations
│   ├── 🌐 http.sh             # HTTP client wrapper (curl / wget)
│   ├── 📦 packages.sh         # Package management abstraction
│   ├── 💬 prompts.sh          # Interactive user prompts
│   ├── 🔁 retry.sh            # Retry helpers and backoff logic
│   ├── 🪤 trap.sh             # Signal handling & cleanup helpers
│   ├── 🔧 services.sh         # System service management
│   ├── 🔤 strings.sh          # String manipulation
│   ├── 🖥️ system.sh           # System information and detection
│   ├── 💾 system-mount.sh     # Safe mounting/unmounting utilities
│   ├── ⏰ time.sh             # Time and date utilities
│   ├── 🛠️ utils.sh            # General purpose utilities
│   └── ✅ validation.sh       # Input validation functions
└── 📂 tests/                  # Comprehensive test suite
    ├── 📄 README.md           # Test documentation
    ├── 🧪 test_helper.sh      # Test helper functions
    ├── 🧪 test_ansi.bats      # ANSI formatting tests
    └── 🧪 test_*.bats         # Individual module tests (BATS framework)
```

## ✨ Key Features

- 🎨 **Rich Logging** - Color-coded logging with timestamps, multiple log levels, and configurable minimum level filtering
- 🌈 **ANSI Formatting** - Comprehensive terminal colors and text formatting utilities
- ✅ **Input Validation** - Comprehensive validation for files, directories, emails, URLs, and more
- 🖥️ **System Detection** - Auto-detect system information using DMI data
- 📁 **File Operations** - Backup creation, directory management, path resolution
- 🗃️ **FileSystem Operations** - Comprehensive file system operations including file manipulation, permissions, symlinks, and path analysis
- 🌐 **Network Operations** - Network utilities including ping, hostname resolution, port checking, file downloads, and URL validation
- 🌐 **HTTP Operations** - Lightweight HTTP GET/POST/status helpers and downloads (curl/wget wrapper)
- 📦 **Package Management** - A small abstraction over common Linux package managers (install/update/installed checks)
- 🔐 **Crypto Utilities** - SHA-256 hashing, checksum verification, UUID v4 generation, and random strings
- ⏰ **Time Utilities** - Epoch/ISO-8601 helpers, formatting/parsing, and duration utilities
- ⚡ **Process Execution** - Background process management, command execution with capture, timeout handling, and process monitoring
- 🚀 **Application Management** - Install, remove, and manage applications across different Linux distributions (Docker support included)
- 🔤 **String Manipulation** - Comprehensive string processing utilities including case conversion, trimming, and validation
- 💬 **User Interaction** - Interactive prompts, confirmations, password input, and menu selections
- 🛠️ **Utility Functions** - Retry logic, human-readable formatting, random string generation
- ⚠️ **Signal Handling** - Graceful script termination and cleanup
- 🎯 **Argument Parsing** - Robust command-line argument parsing

## ⚡ Quick Start

```bash
#!/bin/bash

# Source the utility library
source "lib/bash-utils.sh"

# Use logging functions
log_info "Starting application..."
log_success "Operation completed successfully!"

# Use ANSI formatting
echo "$(ansi_bold)Bold text$(ansi_reset) and $(ansi_red)red text$(ansi_reset)"

# Validate inputs
if ! validate_email "user@example.com"; then
    log_error "Invalid email address"
    exit 1
fi

# System detection
log_info "Running on: $(system_get_distro)"
```

## 📦 Installation

### As a Git Submodule (Recommended)


### Method 1: Git Submodule (Recommended)
```bash
# Add as a git submodule
git submodule add https://github.com/dolpa/bash-utils.git lib/bash-utils

# Initialize and update
git submodule update --init --recursive
```

### Method 2: Direct Download
```bash
# Download the main loader
curl -o lib/bash-utils.sh https://raw.githubusercontent.com/dolpa/bash-utils/main/bash-utils.sh

# Download all modules (recommended)
git clone https://github.com/dolpa/bash-utils.git lib/bash-utils
```

### Method 3: Package Manager Integration
```bash
# Add to your project's package.json scripts or Makefile
make install-deps:
	@git submodule update --init --recursive lib/bash-utils
```

## 🚀 Quick Start


### Basic Usage
```bash
#!/bin/bash

# Source the utility library
source "$(dirname "${BASH_SOURCE[0]}")/lib/bash-utils/bash-utils.sh"

# Enable verbose logging
export BASH_UTILS_VERBOSE=true


# Use logging functions
log_info "🚀 Starting application"
log_success "✅ Operation completed successfully"
log_warning "⚠️ This is a warning"

# Use any available functions
log_info "Application started"
validate_file "/etc/passwd"
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BASH_UTILS_VERBOSE` | Enable verbose logging | `false` |
| `BASH_UTILS_LOG_LEVEL` | Set minimum log level threshold (`TRACE`..`CRITICAL` or numeric `0`..`6`) | `INFO` |
| `BASH_UTILS_COLOR` | Enable/disable colors | `auto` |
| `BASH_UTILS_LOG_FILE` | Log to file | `""` |
| `BASH_UTILS_HTTP_TIMEOUT` | Timeout (seconds) for HTTP operations | `10` |

`BASH_UTILS_LOG_LEVEL` suppresses any message below the configured severity.
Examples: `WARNING` hides `TRACE/DEBUG/INFO/SUCCESS`; `4` behaves the same as `WARNING`.

## 📚 Module Reference

### 🎨 ANSI Formatting (ansi.sh)

Comprehensive ANSI color and formatting utilities for terminal output.

#### Text Colors
| Function | Description |
|----------|-------------|
| `ansi_red <text>` | Print text in red |
| `ansi_green <text>` | Print text in green |
| `ansi_blue <text>` | Print text in blue |
| `ansi_yellow <text>` | Print text in yellow |
| `ansi_magenta <text>` | Print text in magenta |
| `ansi_cyan <text>` | Print text in cyan |
| `ansi_white <text>` | Print text in white |
| `ansi_black <text>` | Print text in black |
| `ansi_gray <text>` | Print text in gray |
| `ansi_purple <text>` | Print text in purple |

#### Bright Colors
| Function | Description |
|----------|-------------|
| `ansi_bright_red <text>` | Print text in bright red |
| `ansi_bright_green <text>` | Print text in bright green |
| `ansi_bright_yellow <text>` | Print text in bright yellow |
| `ansi_bright_blue <text>` | Print text in bright blue |
| `ansi_bright_purple <text>` | Print text in bright purple |
| `ansi_bright_cyan <text>` | Print text in bright cyan |

#### Text Styles
| Function | Description |
|----------|-------------|
| `ansi_bold <text>` | Print bold text |
| `ansi_dim <text>` | Print dimmed text |
| `ansi_italic <text>` | Print italic text |
| `ansi_underline <text>` | Print underlined text |
| `ansi_blink <text>` | Print blinking text |
| `ansi_reverse <text>` | Print text with reversed foreground/background |
| `ansi_strikethrough <text>` | Print strikethrough text |

#### Background Colors
| Function | Description |
|----------|-------------|
| `ansi_bg_red <text>` | Print text with red background |
| `ansi_bg_green <text>` | Print text with green background |
| `ansi_bg_yellow <text>` | Print text with yellow background |
| `ansi_bg_blue <text>` | Print text with blue background |

#### Composite Functions
| Function | Description |
|----------|-------------|
| `ansi_success <text>` | Green text with checkmark |
| `ansi_error <text>` | Red text with X mark |
| `ansi_warning <text>` | Yellow text with warning icon |
| `ansi_info <text>` | Blue text with info icon |
| `ansi_header <text>` | Bold white text for section headers |
| `ansi_code <text>` | Monospace-styled inline code text |

#### Utilities
| Function | Description |
|----------|-------------|
| `ansi_strip <text>` | Remove ANSI codes from text |
| `ansi_length <text>` | Get visible text length (excluding ANSI codes) |
| `ansi_reset` | Reset all formatting |
| `ansi_supports_color` | Return 0 if the terminal supports colors |
| `ansi_test_colors` | Print a color palette test to stdout |
| `ansi_clear_line` | Clear current line |
| `ansi_clear_screen` | Clear entire screen |

#### Example Usage
```bash
source modules/ansi.sh

echo "$(ansi_bold)$(ansi_red)Bold Red Text$(ansi_reset)"
echo "$(ansi_success "Operation completed")"
echo "$(ansi_warning "This is a warning")"

# Background colors
echo "$(ansi_bg_blue)$(ansi_white)White text on blue background$(ansi_reset)"

# Strip ANSI codes for logging to files
clean_text=$(ansi_strip "$(ansi_red)Colored text$(ansi_reset)")
echo "$clean_text" >> logfile.txt
```
log_info "Starting application"
log_success "Operation completed successfully"
log_warning "This is a warning"
log_error "An error occurred"

# Validate inputs before processing
if ! validate_file "/etc/passwd" "System password file"; then
    log_error "❌ Required file missing"
    exit 1
fi

# Check system requirements
if ! check_privileges "This operation requires root access"; then
    log_error "❌ Insufficient privileges"
    exit 1
fi

log_info "✅ All checks passed - proceeding with operation"
```

### Advanced Examples
```bash
#!/bin/bash
source lib/bash-utils/bash-utils.sh

# Set up graceful exit handling
setup_signal_handlers cleanup_function

# Use interactive prompts
if confirm "🔄 Do you want to update the system?" "n"; then
    log_info "🔄 Updating system packages..."
    
    # Use retry logic with exponential backoff
    if retry 3 2 10 apt-get update; then
        log_success "✅ System updated successfully"
    else
        log_error "❌ Failed to update system after retries"
        exit 1
    fi
fi

# Show progress for long operations
deploy_application() {
    log_header "🚀 Deploying Application"
    
    log_step 1 "Building application"
    build_app &
    show_spinner $! "Building..."
    
    log_step 2 "Running tests"
    run_tests &
    show_spinner $! "Testing..."
    
    log_step 3 "Deploying to production"
    deploy_prod &
    show_spinner $! "Deploying..."
    
    log_success "🎉 Deployment completed!"
    log_info "📊 Build time: $(seconds_to_human $SECONDS)"
}

cleanup_function() {
    log_info "🧹 Cleaning up temporary files..."
    # Your cleanup code here
}
```

## ⚙️ Configuration

Configure the library behavior using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `BASH_UTILS_VERBOSE` | `false` | Enable verbose/debug logging |
| `BASH_UTILS_DEBUG` | `false` | Enable trace-level debugging |
| `BASH_UTILS_TIMESTAMP_FORMAT` | `'%Y-%m-%d %H:%M:%S'` | Log timestamp format |
| `BASH_UTILS_LOG_LEVEL` | `"INFO"` | Minimum log level (name: TRACE/DEBUG/INFO/SUCCESS/WARNING/ERROR/CRITICAL, or numeric: 0..6) |
| `BASH_UTILS_NETWORK_TIMEOUT` | `5` | Network operation timeout in seconds |
| `NO_COLOR` | `unset` | Disable color output when set to `1` |

Log level numeric mapping: `TRACE=0`, `DEBUG=1`, `INFO=2`, `SUCCESS=3`, `WARNING=4`, `ERROR=5`, `CRITICAL=6`.
Any log with a lower numeric level than `BASH_UTILS_LOG_LEVEL` is ignored.

### Example Configuration
```bash
# Enable verbose output with custom formatting
export BASH_UTILS_VERBOSE=true
export BASH_UTILS_TIMESTAMP_FORMAT='%H:%M:%S'

# Set longer network timeouts for slow connections
export BASH_UTILS_NETWORK_TIMEOUT=30

# Disable colors for CI/CD environments
export NO_COLOR=1

source bash-utils.sh
```

## 📚 API Reference

### 🎨 Logging Functions

| Function | Description | Example |
|----------|-------------|---------|
| `log_trace(message...)` | Trace-level logging (requires `BASH_UTILS_DEBUG=true` and passes `BASH_UTILS_LOG_LEVEL`) | `log_trace "Variable value: $var"` |
| `log_debug(message...)` | Debug-level logging (requires `BASH_UTILS_VERBOSE=true` or `BASH_UTILS_DEBUG=true`, and passes `BASH_UTILS_LOG_LEVEL`) | `log_debug "Processing file: $file"` |
| `log_info(message...)` | Informational messages | `log_info "✅ Process completed"` |
| `log_success(message...)` | Success messages (green) | `log_success "🎉 Deployment successful"` |
| `log_warning(message...)` | Warning messages (yellow) | `log_warning "⚠️ Deprecated function"` |
| `log_warn(message...)` | Alias for `log_warning` | `log_warn "⚠️ Deprecated function"` |
| `log_error(message...)` | Error messages (red, to stderr) | `log_error "❌ File not found"` |
| `log_critical(message...)` | Critical errors (red background) | `log_critical "💥 System failure"` |
| `log_fatal(message...)` | Alias for `log_critical` | `log_fatal "💥 System failure"` |
| `log_to_file(level, file, message...)` | Print a log message and append a formatted entry to a log file | `log_to_file "info" "/tmp/app.log" "Started successfully"` |
| `log_header(message...)` | Section headers with borders | `log_header "🚀 Starting Deployment"` |
| `log_section(message...)` | Subsection headers | `log_section "📦 Installing packages"` |
| `log_step(number, message)` | Numbered step indicators | `log_step 1 "Preparing environment"` |

### ✅ Validation Functions

#### Core Validation Functions
| Function | Description | Example |
|----------|-------------|---------|
| `command_exists(cmd)` | Check if command is available | `command_exists docker && echo "Docker available"` |
| `is_root()` | Check if running as root | `is_root || { log_error "Root required"; exit 1; }` |
| `is_sudo()` | Check if running with sudo | `is_sudo && log_info "Running with sudo"` |
| `check_privileges([message])` | Ensure root/sudo access | `check_privileges "Installation requires root"` |
| `validate_file(path, [desc])` | Validate file existence | `validate_file "/etc/config" "Config file"` |
| `validate_directory(path, [desc])` | Validate directory existence | `validate_directory "/var/log" "Log directory"` |
| `validate_not_empty(var, [name])` | Check variable is not empty | `validate_not_empty "$API_KEY" "API key"` |
| `validate_system_name(name)` | Validate system name format | `validate_system_name "$hostname"` |
| `validate_email(email)` | Validate email format | `validate_email "$user_email"` |
| `validate_url(url)` | Validate URL format | `validate_url "$api_endpoint"` |
| `validate_port(port)` | Validate port number (1-65535) | `validate_port "$service_port"` |

#### Network Validation Functions
| Function | Description | Example |
|----------|-------------|---------|
| `validate_ipv4(ip)` | Validate IPv4 address format | `validate_ipv4 "192.168.1.1" && echo "Valid IPv4"` |
| `validate_ipv6(ip)` | Validate IPv6 address format | `validate_ipv6 "2001:db8::1" && echo "Valid IPv6"` |
| `validate_mac_address(mac)` | Validate MAC address format | `validate_mac_address "00:1B:44:11:3A:B7"` |

#### Data Format Validation Functions
| Function | Description | Example |
|----------|-------------|---------|
| `validate_date(date)` | Validate date format (YYYY-MM-DD) | `validate_date "2023-12-25" && echo "Valid date"` |
| `validate_phone_number(phone)` | Validate phone number format | `validate_phone_number "555-123-4567"` |
| `validate_json(json_string)` | Validate JSON format | `validate_json '{"key":"value"}' && echo "Valid JSON"` |

#### Numeric Validation Functions
| Function | Description | Example |
|----------|-------------|---------|
| `validate_number_range(number, min, max)` | Validate number within range | `validate_number_range "$age" 18 100` |
| `validate_positive_number(number)` | Validate positive number | `validate_positive_number "$count" && echo "Valid positive"` |

#### System Validation Functions
| Function | Description | Example |
|----------|-------------|---------|
| `validate_process_running(pid_or_name)` | Check if process is running | `validate_process_running "nginx" && echo "Nginx running"` |
| `validate_disk_space(path, required_mb)` | Check available disk space | `validate_disk_space "/var" 1000` |
| `validate_username(username)` | Validate username format | `validate_username "user123" && echo "Valid username"` |
| `validate_password_strength(password)` | Check password strength | `validate_password_strength "MyP@ss123"` |
| `validate_env_var(var_name)` | Check environment variable is set | `validate_env_var "HOME" && echo "HOME is set"` |

### 📁 File Operations

| Function | Description | Example |
|----------|-------------|---------|
| `create_backup(file, [dir], [name])` | Create timestamped backup | `backup=$(create_backup "/etc/config")` |
| `ensure_directory(path, [perms])` | Create directory if missing | `ensure_directory "/var/app/logs" 755` |
| `get_absolute_path(path)` | Get absolute path | `abs_path=$(get_absolute_path "./config")` |
| `get_script_dir()` | Get calling script's directory | `script_dir=$(get_script_dir)` |
| `get_script_name()` | Get calling script's name | `script_name=$(get_script_name)` |

### 📂 Filesystem Operations

#### File Type Checks
| Function | Description | Example |
|----------|-------------|---------|
| `is_path_file(path)` | Check if path is a regular file | `is_path_file "$config" && source "$config"` |
| `is_path_directory(path)` | Check if path is a directory | `is_path_directory "$dir" || mkdir -p "$dir"` |
| `is_path_symlink(path)` | Check if path is a symbolic link | `is_path_symlink "$link" && echo "Is symlink"` |
| `is_path_fifo(path)` | Check if path is a named pipe | `is_path_fifo "$pipe"` |
| `is_path_socket(path)` | Check if path is a socket | `is_path_socket "$sock"` |
| `is_path_block(path)` | Check if path is a block device | `is_path_block "/dev/sda"` |
| `is_path_char(path)` | Check if path is a character device | `is_path_char "/dev/null"` |
| `get_path_type(path)` | Return type string (file/directory/symlink/…) | `type=$(get_path_type "/etc/passwd")` |

#### Permission Checks
| Function | Description | Example |
|----------|-------------|---------|
| `is_path_readable(path)` | Check if path is readable | `is_path_readable "$file" && cat "$file"` |
| `is_path_writable(path)` | Check if path is writable | `is_path_writable "$dir" || exit 1` |
| `is_path_executable(path)` | Check if path is executable | `is_path_executable "$script" && bash "$script"` |
| `is_path_hidden(path)` | Check if path is a dotfile/hidden | `is_path_hidden "$file" && echo "Hidden"` |

#### Content Checks
| Function | Description | Example |
|----------|-------------|---------|
| `is_path_empty(path)` | Check if file or directory is empty | `is_path_empty "$dir" && echo "Nothing here"` |
| `is_path_nonempty(path)` | Check if file or directory is non-empty | `is_path_nonempty "$log" && tail "$log"` |

#### File Metadata
| Function | Description | Example |
|----------|-------------|---------|
| `get_file_size(path)` | Get file size in bytes | `size=$(get_file_size "/var/log/syslog")` |
| `get_file_mod_time(path)` | Get file modification time (epoch) | `mtime=$(get_file_mod_time "$file")` |
| `get_file_perm(path)` | Get octal permissions | `perms=$(get_file_perm "/etc/passwd")` |
| `get_file_owner(path)` | Get file owner username | `owner=$(get_file_owner "$file")` |
| `get_file_group(path)` | Get file group name | `group=$(get_file_group "$file")` |

#### Path Components
| Function | Description | Example |
|----------|-------------|---------|
| `get_basename(path)` | Get filename from path | `name=$(get_basename "/etc/passwd")` |
| `get_dirname(path)` | Get directory part of path | `dir=$(get_dirname "/etc/passwd")` |
| `get_file_extension(path)` | Get file extension (without dot) | `ext=$(get_file_extension "archive.tar.gz")` |
| `get_filename_without_extension(path)` | Get filename without extension | `base=$(get_filename_without_extension "file.txt")` |
| `get_canonical_path(path)` | Resolve symlinks to absolute path | `real=$(get_canonical_path "./link")` |
| `readlink_path(path)` | Read symlink target | `target=$(readlink_path "/usr/bin/python")` |

#### File Operations
| Function | Description | Example |
|----------|-------------|---------|
| `copy_file(src, dst)` | Copy file | `copy_file "/etc/config" "/backup/config"` |
| `move_file(src, dst)` | Move/rename file | `move_file "/tmp/file" "/var/app/file"` |
| `delete_file(path)` | Delete a file | `delete_file "/tmp/temp.txt"` |
| `delete_directory(path)` | Delete a directory recursively | `delete_directory "/tmp/work"` |
| `touch_file(path)` | Create file or update timestamps | `touch_file "/var/run/app.pid"` |
| `truncate_file(path)` | Empty file contents without deleting | `truncate_file "/var/log/app.log"` |
| `read_file(path)` | Print file contents to stdout | `content=$(read_file "$config")` |
| `write_file(path, content)` | Write content to file (overwrite) | `write_file "/tmp/out.txt" "hello"` |
| `append_to_file(path, content)` | Append content to file | `append_to_file "/tmp/log" "new line"` |
| `symlink_file(target, link)` | Create a symbolic link | `symlink_file "/opt/app" "/usr/local/app"` |
| `hardlink_file(src, dst)` | Create a hard link | `hardlink_file "/data/file" "/data/file.bak"` |

#### Permission Operations
| Function | Description | Example |
|----------|-------------|---------|
| `chmod_file(path, mode)` | Set file permissions | `chmod_file "/usr/bin/script" 755` |
| `chown_file(path, owner)` | Set file owner | `chown_file "/var/app" "www-data"` |
| `chgrp_file(path, group)` | Set file group | `chgrp_file "/var/app" "www-data"` |

#### Temporary Files
| Function | Description | Example |
|----------|-------------|---------|
| `create_temp_file([content])` | Create a temporary file | `tmp=$(create_temp_file "initial content")` |
| `create_temp_dir()` | Create a temporary directory | `tmpdir=$(create_temp_dir)` |

#### Listing and Search
| Function | Description | Example |
|----------|-------------|---------|
| `list_directory(path, [pattern])` | List directory contents | `list_directory "/etc" "*.conf"` |
| `list_files_recursive(path, [pattern])` | Recursively list files | `list_files_recursive "/var/log" "*.log"` |
| `find_files_by_name(dir, name)` | Find files matching name pattern | `find_files_by_name "/etc" "*.conf"` |
| `find_files_by_pattern(dir, pattern)` | Find files matching content pattern | `find_files_by_pattern "/var/log" "ERROR"` |

### 🌐 Network Operations

#### Core Network Functions
| Function | Description | Example |
|----------|-------------|---------|
| `ping_host(host, [count])` | Ping remote host | `ping_host "google.com" && echo "Online"` |
| `resolve_ip(hostname)` | Resolve hostname to IP | `ip=$(resolve_ip "github.com")` |
| `is_port_open(host, port)` | Check if TCP port is open | `is_port_open "localhost" 80 && echo "Web server running"` |
| `download_file(url, dest)` | Download file from URL | `download_file "$url" "/tmp/download.zip"` |
| `check_url(url)` | Verify URL is reachable | `check_url "$api_endpoint" && echo "API available"` |
| `get_public_ip()` | Get public IP address | `public_ip=$(get_public_ip)` |

#### Interface Management
| Function | Description | Example |
|----------|-------------|---------|
| `get_local_ips()` | Get all local IP addresses | `ips=$(get_local_ips)` |
| `get_default_gateway()` | Get default gateway IP | `gateway=$(get_default_gateway)` |
| `get_interface_info(interface)` | Get interface information | `info=$(get_interface_info "eth0")` |
| `get_interface_stats(interface)` | Get interface statistics | `stats=$(get_interface_stats "eth0")` |

#### Port and Connectivity
| Function | Description | Example |
|----------|-------------|---------|
| `scan_ports(host, start_port, end_port)` | Scan port range on host | `scan_ports "192.168.1.1" 80 443` |
| `test_connectivity(host, [timeout])` | Test network connectivity | `test_connectivity "8.8.8.8" 5` |
| `wait_for_port(host, port, [timeout])` | Wait for port to be available | `wait_for_port "db-server" 5432 60` |
| `check_internet_connection()` | Check internet connectivity | `check_internet_connection && echo "Online"` |

#### DNS Operations
| Function | Description | Example |
|----------|-------------|---------|
| `dns_lookup(hostname, [record_type])` | DNS lookup with record type | `dns_lookup "example.com" "A"` |
| `dns_reverse_lookup(ip)` | Reverse DNS lookup | `hostname=$(dns_reverse_lookup "8.8.8.8")` |
| `get_mx_records(domain)` | Get MX records for domain | `mx_records=$(get_mx_records "example.com")` |

#### SSL and Security
| Function | Description | Example |
|----------|-------------|---------|
| `check_ssl_cert(hostname, port)` | Check SSL certificate validity | `check_ssl_cert "example.com" 443` |
| `get_ssl_cert_info(hostname, port)` | Get SSL certificate information | `cert_info=$(get_ssl_cert_info "example.com" 443)` |

#### Network Configuration
| Function | Description | Example |
|----------|-------------|---------|
| `add_route(destination, gateway, [interface])` | Add network route | `add_route "192.168.2.0/24" "192.168.1.1"` |
| `delete_route(destination)` | Delete network route | `delete_route "192.168.2.0/24"` |
| `flush_dns_cache()` | Flush DNS cache | `flush_dns_cache` |

#### Bandwidth and Monitoring
| Function | Description | Example |
|----------|-------------|---------|
| `test_bandwidth(host, [timeout])` | Test bandwidth to host | `speed=$(test_bandwidth "speedtest.example.com")` |
| `monitor_connection(interface, [interval])` | Monitor network interface | `monitor_connection "eth0" 5` |
| `get_network_usage(interface)` | Get network usage statistics | `usage=$(get_network_usage "eth0")` |

### 🌐 HTTP Operations

Lightweight HTTP client wrapper. Prefers `curl`, falls back to `wget`.

#### Core HTTP Methods
| Function | Description | Example |
|----------|-------------|---------|
| `http_get(url)` | GET request; write response body to stdout | `html=$(http_get "https://example.com")` |
| `http_post(url, data)` | POST data; write response body to stdout | `resp=$(http_post "$endpoint" '{"ok":true}')` |
| `http_put(url, data)` | PUT data; write response body to stdout | `resp=$(http_put "$endpoint" '{"data":"value"}')` |
| `http_patch(url, data)` | PATCH data; write response body to stdout | `resp=$(http_patch "$endpoint" '{"field":"new_value"}')` |
| `http_delete(url)` | DELETE request; write response body to stdout | `resp=$(http_delete "$endpoint")` |
| `http_head(url)` | HEAD request; return status only | `http_head "$url" && echo "Resource exists"` |
| `http_options(url)` | OPTIONS request; get allowed methods | `methods=$(http_options "$endpoint")` |
| `http_status(url)` | Print HTTP status code to stdout | `code=$(http_status "https://example.com")` |
| `http_download(url, dest)` | Download URL to a local file path | `http_download "$url" "/tmp/file.bin"` |

#### Generic HTTP Request
| Function | Description | Example |
|----------|-------------|---------|
| `http_request(method, url, [data])` | Generic HTTP request with any method | `resp=$(http_request "PATCH" "$url" '{"data":"value"}')` |

#### Authentication Methods
| Function | Description | Example |
|----------|-------------|---------|
| `http_request_basic(method, url, username, password, [data])` | HTTP request with basic auth | `resp=$(http_request_basic "GET" "$url" "user" "pass")` |
| `http_request_bearer(method, url, token, [data])` | HTTP request with bearer token | `resp=$(http_request_bearer "GET" "$url" "token123")` |
| `http_request_api_key(method, url, header_name, api_key, [data])` | HTTP request with API key header | `resp=$(http_request_api_key "GET" "$url" "X-API-Key" "key123")` |

#### File Operations
| Function | Description | Example |
|----------|-------------|---------|
| `http_upload_file(url, file_path, field_name)` | Upload file via HTTP POST | `resp=$(http_upload_file "$upload_url" "/path/to/file.txt" "document")` |
| `http_upload_multipart(url, form_data...)` | Upload multipart form data | `resp=$(http_upload_multipart "$url" "field1=value1" "file=@/path/file.txt")` |

#### Response Processing
| Function | Description | Example |
|----------|-------------|---------|
| `http_get_headers(url)` | Get response headers only | `headers=$(http_get_headers "$url")` |
| `http_get_json(url)` | GET request expecting JSON response | `data=$(http_get_json "$api_endpoint")` |
| `http_get_status_text(status_code)` | Convert status code to text | `text=$(http_get_status_text "404")` |
| `parse_json_response(json_string, key)` | Extract value from JSON response | `value=$(parse_json_response "$json" "data.user.name")` |

#### Utility Functions
| Function | Description | Example |
|----------|-------------|---------|
| `http_retry(max_attempts, function, args...)` | Retry HTTP request with backoff | `http_retry 3 http_get "$unreliable_url"` |
| `http_is_success(status_code)` | Check if status code indicates success | `http_is_success "$code" && echo "Request successful"` |
| `http_follow_redirects(url)` | Follow redirects and get final URL | `final_url=$(http_follow_redirects "$short_url")` |

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `BASH_UTILS_HTTP_TIMEOUT` | Timeout (seconds) for HTTP operations | `10` |

### 🔧 Process Management

| Function | Description | Example |
|----------|-------------|---------|
| `exec_run(cmd...)` | Execute command and return status | `exec_run ls -la /tmp` |
| `exec_run_capture(out_var, err_var, cmd...)` | Execute and capture output | `exec_run_capture stdout stderr ls /nonexistent` |
| `exec_background(cmd...)` | Start command in background | `pid=$(exec_background sleep 30)` |
| `exec_is_running(pid)` | Check if process is running | `exec_is_running "$pid" && echo "Still running"` |
| `exec_kill(pid, [signal])` | Send signal to process | `exec_kill "$pid" TERM` |
| `exec_wait(pid, [timeout])` | Wait for process with timeout | `exec_wait "$pid" 30 || echo "Timeout"` |
| `exec_wait_result(pid, [timeout])` | Wait for process and return its exit code | `exec_wait_result "$pid" 30` |
| `exec_run_with_timeout(timeout, cmd...)` | Run command with timeout | `exec_run_with_timeout 10 curl "$url"` |

### 🌍 Environment Variables (env.sh)

| Function | Description | Example |
|----------|-------------|---------|
| `env_require(var, [message])` | Exit if variable is unset or empty | `env_require "API_KEY" "API_KEY is required"` |
| `env_default(var, value)` | Set variable default if unset or empty | `env_default "TIMEOUT" "30"` |
| `env_bool(var)` | Normalise variable to `true`/`false` | `env_bool "VERBOSE"` |
| `env_from_file(file)` | Load `KEY=value` pairs from a `.env` file | `env_from_file ".env"` |

### 🔧 Service Management (services.sh)

Thin wrapper over `systemctl` (falls back to legacy `service` command).

| Function | Description | Example |
|----------|-------------|---------|
| `service_exists(name)` | Check if a service unit exists | `service_exists nginx && echo "nginx is installed"` |
| `service_running(name)` | Check if a service is currently active | `service_running nginx || start_service nginx` |
| `service_restart(name)` | Restart a service | `service_restart nginx` |
| `service_enable(name)` | Enable a service to start at boot | `service_enable nginx` |

### 📦 Package Management (packages.sh)

| Function | Description | Example |
|----------|-------------|---------|
| `pkg_detect_manager()` | Detect available package manager | `mgr=$(pkg_detect_manager)` |
| `pkg_install(package...)` | Install one or more packages | `pkg_install curl wget git` |
| `pkg_update()` | Update package manager index | `pkg_update` |
| `pkg_installed(package)` | Check if a package is installed | `pkg_installed docker && echo "Docker ready"` |

### 🚀 Application Management

| Function | Description | Example |
|----------|-------------|---------|
| `app_is_installed(app)` | Check if application is installed | `app_is_installed docker && echo "Docker available"` |
| `app_install_docker()` | Install Docker Engine | `app_install_docker` |
| `app_remove_docker()` | Remove Docker Engine | `app_remove_docker` |

### 🎯 Argument Parsing

| Function | Description | Example |
|----------|-------------|---------|
| `args_set_flags(flag...)` | Register boolean flags | `args_set_flags --force --dry-run` |
| `args_set_values(option...)` | Register value options | `args_set_values --output --input` |
| `args_set_usage(string)` | Set usage help string | `args_set_usage "--input <file> --output <file>"` |
| `args_usage` | Print usage string | `args_usage` |
| `args_parse(argv...)` | Parse command-line arguments | `args_parse "$@"` |
| `args_get_flag(flag, [fallback])` | Check if flag is set | `args_get_flag --force && echo "Force mode"` |
| `args_get_value(option, [default])` | Get option value | `outfile=$(args_get_value --output "default.txt")` |
| `args_get_positional(index)` | Get positional argument | `first_arg=$(args_get_positional 0)` |

### 📝 String Processing

#### Basic String Operations
| Function | Description | Example |
|----------|-------------|---------|
| `str_upper(string)` | Convert to uppercase | `upper=$(str_upper "hello")` |
| `str_lower(string)` | Convert to lowercase | `lower=$(str_lower "HELLO")` |
| `str_title(string)` | Convert to title case | `title=$(str_title "hello world")` |
| `str_length(string)` | Get string length | `len=$(str_length "$text")` |
| `str_trim(string)` | Remove leading/trailing whitespace | `clean=$(str_trim "  text  ")` |
| `str_ltrim(string)` | Remove leading whitespace only | `clean=$(str_ltrim "  text  ")` |
| `str_rtrim(string)` | Remove trailing whitespace only | `clean=$(str_rtrim "  text  ")` |
| `str_contains(string, substring)` | Check if string contains substring | `str_contains "$text" "error" && echo "Error found"` |
| `str_replace(string, search, replace)` | Replace all occurrences | `new=$(str_replace "$text" "old" "new")` |
| `str_split(string, delimiter, array_name)` | Split string into array | `str_split "$csv" "," parts` |
| `str_join(delimiter, word...)` | Join words with delimiter | `path=$(str_join "/" "usr" "local" "bin")` |

#### Advanced String Functions
| Function | Description | Example |
|----------|-------------|---------|
| `str_is_email(string)` | Validate email format | `str_is_email "user@example.com" && echo "Valid email"` |
| `str_is_url(string)` | Validate URL format | `str_is_url "https://example.com" && echo "Valid URL"` |
| `str_is_numeric(string)` | Check if string is numeric | `str_is_numeric "123" && echo "Is number"` |
| `str_is_alphanumeric(string)` | Check if string is alphanumeric | `str_is_alphanumeric "abc123" && echo "Is alphanumeric"` |
| `str_starts_with(string, prefix)` | Check if string starts with prefix | `str_starts_with "$file" "/tmp/" && echo "Temp file"` |
| `str_ends_with(string, suffix)` | Check if string ends with suffix | `str_ends_with "$file" ".txt" && echo "Text file"` |
| `str_count_occurrences(string, substring)` | Count substring occurrences | `count=$(str_count_occurrences "$text" "error")` |
| `str_remove_prefix(string, prefix)` | Remove prefix from string | `name=$(str_remove_prefix "$path" "/tmp/")` |
| `str_remove_suffix(string, suffix)` | Remove suffix from string | `base=$(str_remove_suffix "$file" ".txt")` |
| `str_pad_left(string, length, [char])` | Pad string to length on left | `padded=$(str_pad_left "42" 5 "0")` |
| `str_pad_right(string, length, [char])` | Pad string to length on right | `padded=$(str_pad_right "test" 10 ".")` |
| `str_reverse(string)` | Reverse string characters | `reversed=$(str_reverse "hello")` |
| `str_to_snake(string)` | Convert to snake_case | `snake=$(str_to_snake "CamelCase")` |
| `str_to_kebab(string)` | Convert to kebab-case | `kebab=$(str_to_kebab "CamelCase")` |
| `str_to_camel(string)` | Convert to camelCase | `camel=$(str_to_camel "snake_case")` |
| `str_url_encode(string)` | URL encode string | `encoded=$(str_url_encode "hello world")` |
| `str_url_decode(string)` | URL decode string | `decoded=$(str_url_decode "hello%20world")` |
| `str_escape_html(string)` | Escape HTML characters | `safe=$(str_escape_html "<script>alert('hi')</script>")` |
| `str_strip_html(string)` | Remove HTML tags | `clean=$(str_strip_html "<b>Bold</b> text")` |
| `str_truncate(string, length, [suffix])` | Truncate string to length | `short=$(str_truncate "$long_text" 50 "...")` |
| `str_word_count(string)` | Count words in string | `words=$(str_word_count "Hello world")` |
| `str_char_at(string, index)` | Get character at index | `char=$(str_char_at "hello" 1)` |
| `str_substring(string, start, [length])` | Extract substring | `sub=$(str_substring "hello" 1 3)` |
| `str_repeat(string, count)` | Repeat string N times | `repeated=$(str_repeat "abc" 3)` |
| `str_version_compare(version1, version2)` | Compare version strings | `str_version_compare "1.2.3" "1.2.4"` |
| `str_random([length])` | Generate random string | `random=$(str_random 16)` |

### 💬 User Interaction

| Function | Description | Example |
|----------|-------------|---------|
| `prompt_input(prompt, [default])` | Get user input | `name=$(prompt_input "Enter name" "default")` |
| `prompt_password(prompt)` | Get password input (hidden) | `pass=$(prompt_password "Enter password")` |
| `prompt_confirm(prompt, [default])` | Get yes/no confirmation | `confirm "Continue?" "y" && echo "Proceeding"` |
| `prompt_confirm_yes(prompt)` | Confirm with default yes | `prompt_confirm_yes "Proceed?" || exit 0` |
| `prompt_menu(title, option...)` | Show selection menu | `choice=$(prompt_menu "Select" "Option 1" "Option 2")` |
| `prompt_number(prompt, [min], [max])` | Get numeric input | `num=$(prompt_number "Enter count" 1 100)` |
| `prompt_pause([message])` | Pause and wait for user to press Enter | `prompt_pause "Press Enter to continue..."` |

### 💾 System Mount Functions

Safe mounting and unmounting operations under a configurable base directory. Requires root privileges for most operations.

| Function | Description | Example |
|----------|-------------|---------|
| `mount_set_base_dir(path)` | Set the base directory for mount operations | `mount_set_base_dir "/mnt"` |
| `mount_get_base_dir()` | Get the current base directory | `base_dir=$(mount_get_base_dir)` |
| `mount_set_verbose()` | Enable verbose output for mount operations | `mount_set_verbose` |
| `mount_set_dry_run()` | Enable dry-run mode (show what would be done) | `mount_set_dry_run` |
| `mount_cli_mount(fstype, device, point)` | Mount filesystem under base directory | `mount_cli_mount ext4 /dev/sdb1 backup --mkdir` |
| `mount_cli_umount(point)` | Unmount filesystem from mount point | `mount_cli_umount backup` |
| `mount_cli_status(point)` | Check mount status of a point | `mount_cli_status backup` |
| `mount_cli_list()` | List all mounts under base directory | `mount_cli_list` |
| `mount_is_mounted(target)` | Check if target path is mounted | `mount_is_mounted "/mnt/backup" && echo "Mounted"` |
| `mount_target_path(point)` | Get absolute path for mount point | `target=$(mount_target_path "backup")` |

#### Mount Options
- `--mkdir` - Create target directory if it doesn't exist
- `--opts <options>` - Specify mount options (e.g., "ro,noexec")
- `--mode <mode>` - Use predefined mount mode (resolves to specific options)

#### Usage Examples
```bash
source modules/system-mount.sh

# Set base directory and enable verbose output
mount_set_base_dir "/mnt"
mount_set_verbose

# Mount an external drive
mount_cli_mount ext4 /dev/sdb1 external-drive --mkdir --opts "rw,noatime"

# Check mount status
mount_cli_status external-drive

# List all mounts
mount_cli_list

# Unmount when done
mount_cli_umount external-drive

# Check if something is mounted programmatically
if mount_is_mounted "$(mount_target_path "backup")"; then
    echo "Backup drive is mounted"
fi
```

### 🛠️ Utility Functions

| Function | Description | Example |
|----------|-------------|---------|
| `retry(attempts, delay, max_delay, cmd...)` | Retry with exponential backoff | `retry 3 2 30 curl "$url"` |
| `retry_cmd(attempts, cmd...)` | Retry fixed number of attempts | `retry_cmd 3 curl "$url"` |
| `retry_with_backoff(attempts, initial_delay, cmd...)` | Retry with exponential backoff | `retry_with_backoff 5 2 curl "$url"` |
| `retry_until(timeout_seconds, cmd...)` | Retry until timeout reached | `retry_until 30 curl "$url"` |
| `show_spinner(pid, [message])` | Show progress spinner | `show_spinner $! "Processing..."` |
| `seconds_to_human(seconds)` | Format duration | `duration=$(seconds_to_human 3661)` |
| `bytes_to_human(bytes)` | Format file size | `size=$(bytes_to_human 1536000)` |
| `generate_random_string([length], [chars])` | Generate random string | `token=$(generate_random_string 32)` |
| `setup_signal_handlers([cleanup_func])` | Set up signal handlers | `setup_signal_handlers cleanup` |
| `trap_on_exit(cleanup_func)` | Run cleanup on EXIT | `trap_on_exit cleanup` |
| `trap_signals(signal...)` | Exit gracefully on signals | `trap_signals TERM INT HUP` |
| `with_tempdir(cmd...)` | Run command inside a temp directory | `with_tempdir bash -c "pwd"` |
| `is_semver(version)` | Check semantic version format | `is_semver "$version" && echo "Valid"` |
| `compare_versions(v1, v2)` | Compare semantic versions | `compare_versions "1.2.0" "1.1.0"` |

### 🔐 Crypto Utilities

#### Hashing Functions
| Function | Description | Example |
|----------|-------------|---------|
| `hash_sha256(file)` | Generate SHA-256 hash of file | `hash=$(hash_sha256 "/path/to/file")` |
| `hash_sha1(file)` | Generate SHA-1 hash of file | `hash=$(hash_sha1 "/path/to/file")` |
| `hash_md5(file)` | Generate MD5 hash of file | `hash=$(hash_md5 "/path/to/file")` |
| `hash_sha512(file)` | Generate SHA-512 hash of file | `hash=$(hash_sha512 "/path/to/file")` |
| `hash_verify(file, expected_hash)` | Verify file hash matches expected | `hash_verify "$file" "$known_hash" && echo "Valid"` |

#### Encoding Functions
| Function | Description | Example |
|----------|-------------|---------|
| `base64_encode(string)` | Encode string to base64 | `encoded=$(base64_encode "Hello World")` |
| `base64_decode(string)` | Decode base64 string | `decoded=$(base64_decode "SGVsbG8gV29ybGQ=")` |
| `url_encode(string)` | URL encode string | `encoded=$(url_encode "hello world")` |
| `url_decode(string)` | URL decode string | `decoded=$(url_decode "hello%20world")` |
| `hex_encode(string)` | Convert string to hexadecimal | `hex=$(hex_encode "ABC")` |
| `hex_decode(string)` | Convert hexadecimal to string | `text=$(hex_decode "414243")` |

#### Password and Random Functions
| Function | Description | Example |
|----------|-------------|---------|
| `uuid_generate()` | Generate UUID v4 | `id=$(uuid_generate)` |
| `random_string([length])` | Generate random alphanumeric string | `token=$(random_string 32)` |
| `generate_password([length])` | Generate secure password | `pass=$(generate_password 16)` |
| `password_entropy(password)` | Calculate password entropy | `entropy=$(password_entropy "$pass")` |

#### File Encryption (requires OpenSSL)
| Function | Description | Example |
|----------|-------------|---------|
| `encrypt_file(input, output, password)` | Encrypt file with password | `encrypt_file "secret.txt" "secret.enc" "pass123"` |
| `decrypt_file(input, output, password)` | Decrypt file with password | `decrypt_file "secret.enc" "secret.txt" "pass123"` |
| `encrypt_string(string, password)` | Encrypt string with password | `enc=$(encrypt_string "secret" "pass123")` |
| `decrypt_string(encrypted, password)` | Decrypt string with password | `text=$(decrypt_string "$enc" "pass123")` |

#### HMAC Signatures
| Function | Description | Example |
|----------|-------------|---------|
| `hmac_sign(message, key)` | Generate HMAC signature | `sig=$(hmac_sign "data" "secret_key")` |
| `hmac_verify(message, signature, key)` | Verify HMAC signature | `hmac_verify "data" "$sig" "secret_key" && echo "Valid"` |

### 🕰️ Time Utilities

#### Core Time Functions
| Function | Description | Example |
|----------|-------------|---------|
| `time_now()` | Get current ISO-8601 timestamp (UTC) | `timestamp=$(time_now)` |
| `time_epoch()` | Get current epoch seconds | `epoch=$(time_epoch)` |
| `time_epoch_ms()` | Get current epoch milliseconds | `epoch_ms=$(time_epoch_ms)` |
| `time_epoch_to_iso8601(epoch, [timezone])` | Convert epoch to ISO-8601 | `iso=$(time_epoch_to_iso8601 1640995200 "utc")` |
| `time_parse_iso8601(iso_string)` | Parse ISO-8601 to epoch | `epoch=$(time_parse_iso8601 "2023-01-01T00:00:00Z")` |

#### Time Arithmetic
| Function | Description | Example |
|----------|-------------|---------|
| `time_add_seconds(epoch, seconds)` | Add seconds to epoch time | `new_time=$(time_add_seconds 1640995200 3600)` |
| `time_add_minutes(epoch, minutes)` | Add minutes to epoch time | `new_time=$(time_add_minutes 1640995200 30)` |
| `time_add_hours(epoch, hours)` | Add hours to epoch time | `new_time=$(time_add_hours 1640995200 6)` |
| `time_add_days(epoch, days)` | Add days to epoch time | `new_time=$(time_add_days 1640995200 7)` |
| `time_diff_seconds(epoch1, epoch2)` | Calculate difference in seconds | `diff=$(time_diff_seconds 1640995200 1641000000)` |

#### Duration and Formatting
| Function | Description | Example |
|----------|-------------|---------|
| `time_benchmark(start_epoch, end_epoch)` | Format duration between epochs | `duration=$(time_benchmark 100 102)` |
| `time_seconds_to_human(seconds)` | Convert seconds to human readable | `human=$(time_seconds_to_human 3661)` |
| `time_format_duration(seconds)` | Format duration with units | `formatted=$(time_format_duration 7265)` |
| `time_parse_duration(duration_string)` | Parse duration string to seconds | `seconds=$(time_parse_duration "1h30m")` |
| `time_format_date(epoch, format)` | Format epoch using date format | `date=$(time_format_date 1640995200 "%Y-%m-%d")` |
| `time_get_relative(epoch)` | Get relative time description | `rel=$(time_get_relative 1640995200)` |

#### Timezone Operations
| Function | Description | Example |
|----------|-------------|---------|
| `time_convert_timezone(datetime, from_tz, to_tz)` | Convert between timezones | `converted=$(time_convert_timezone "2023-01-01 12:00:00" "UTC" "America/New_York")` |
| `time_get_timezone()` | Get current system timezone | `tz=$(time_get_timezone)` |
| `time_set_timezone(timezone)` | Set system timezone (requires root) | `time_set_timezone "America/Los_Angeles"` |

#### Date Validation and Scheduling
| Function | Description | Example |
|----------|-------------|---------|
| `time_is_valid_date(date_string)` | Validate date format | `time_is_valid_date "2023-12-25" && echo "Valid date"` |
| `time_matches_cron(cron_pattern, epoch)` | Check if time matches cron pattern | `time_matches_cron "0 0 * * *" 1640995200 && echo "Matches"` |
| `time_next_cron_run(cron_pattern)` | Get next cron execution time | `next=$(time_next_cron_run "0 0 * * *")` |
| `time_is_weekday(epoch)` | Check if epoch is a weekday | `time_is_weekday 1640995200 && echo "Is weekday"` |
| `time_is_weekend(epoch)` | Check if epoch is weekend | `time_is_weekend 1640995200 && echo "Is weekend"` |
| `sleep_until(epoch)` | Sleep until specified epoch time | `sleep_until 1640999999` |

### 🖥️ System Information

#### Hardware and System Info
| Function | Description | Example |
|----------|-------------|---------|
| `get_os_name()` | Get operating system name | `os=$(get_os_name)` |
| `get_os_version()` | Get operating system version | `version=$(get_os_version)` |
| `get_cpu_info()` | Get CPU information | `cpu=$(get_cpu_info)` |
| `get_memory_info()` | Get memory information | `memory=$(get_memory_info)` |
| `get_disk_info()` | Get disk information | `disk=$(get_disk_info)` |
| `get_system_info()` | Get comprehensive system information | `info=$(get_system_info)` |
| `get_architecture()` | Get system architecture | `arch=$(get_architecture)` |
| `detect_virtualization()` | Detect if running in virtual environment | `virt=$(detect_virtualization)` |
| `auto_detect_system()` | Auto-detect system using DMI data | `auto_detect_system` |

#### Performance Monitoring  
| Function | Description | Example |
|----------|-------------|---------|
| `get_cpu_usage()` | Get current CPU usage percentage | `cpu_pct=$(get_cpu_usage)` |
| `get_memory_usage()` | Get current memory usage | `mem_usage=$(get_memory_usage)` |
| `get_disk_usage(path)` | Get disk usage for path | `disk_pct=$(get_disk_usage "/var")` |
| `get_system_load()` | Get system load averages | `load=$(get_system_load)` |
| `get_uptime()` | Get system uptime | `uptime=$(get_uptime)` |
| `check_system_health()` | Perform system health check | `health=$(check_system_health)` |

#### Process Management
| Function | Description | Example |
|----------|-------------|---------|
| `get_process_info(pid)` | Get process information | `info=$(get_process_info 1234)` |
| `kill_process_tree(pid, [signal])` | Kill process and its children | `kill_process_tree 1234 TERM` |
| `start_service(service_name)` | Start system service | `start_service "nginx"` |
| `stop_service(service_name)` | Stop system service | `stop_service "nginx"` |
| `restart_service(service_name)` | Restart system service | `restart_service "nginx"` |
| `get_service_status(service_name)` | Get service status | `status=$(get_service_status "nginx")` |

#### Resource Monitoring
| Function | Description | Example |
|----------|-------------|---------|
| `monitor_system([interval], [duration])` | Monitor system resources | `monitor_system 5 60` |
| `get_top_processes([count])` | Get top processes by resource usage | `top=$(get_top_processes 10)` |
| `check_resource_limits()` | Check system resource limits | `limits=$(check_resource_limits)` |

## 🧪 Testing

The library includes comprehensive tests using the BATS testing framework.

### Running Tests Locally
```bash
# Install BATS if needed (Ubuntu/Debian)
sudo apt-get install bats

# Run all tests
./run-tests.sh

# Run specific test file
bats tests/test_logging.bats

# Run with verbose output
bats -t tests/test_*.bats
```

### Running Tests in Docker
```bash
# Build and run tests in a clean environment
./run-tests-docker.sh

# Or manually
docker build -t bash-utils-test .
docker run --rm bash-utils-test
```

### Test Coverage
- ✅ **Unit Tests** - Individual function testing
- ✅ **Integration Tests** - Module interaction testing  
- ✅ **Error Handling** - Comprehensive error case coverage
- ✅ **Cross-Platform** - Linux and macOS compatibility testing
- ✅ **Mock Support** - Safe testing without system modification

## 🤝 Contributing

We welcome contributions! Please see our contribution guidelines:

### Development Workflow
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Add tests** for new functionality
4. **Ensure** all tests pass (`./run-tests.sh`)
5. **Commit** your changes (`git commit -m 'Add amazing feature'`)
6. **Push** to the branch (`git push origin feature/amazing-feature`)
7. **Submit** a pull request

### Code Standards
- ✅ Follow existing code style and patterns
- ✅ Add comprehensive documentation for new functions
- ✅ Include error handling with proper logging
- ✅ Write tests for all new functionality
- ✅ Use shellcheck for code quality
- ✅ Maintain backward compatibility

### Testing Requirements
- All new functions must have corresponding tests
- Tests should cover both success and failure cases
- Integration tests for complex workflows
- Mock external dependencies appropriately

## 📋 Requirements

### System Requirements
- **Bash** 4.0+ (some features require newer versions)
- **Linux/macOS** (Windows WSL/Git Bash supported)
- **Standard Unix tools** (grep, sed, awk, etc.)

### Optional Dependencies
- **BATS** - For running tests
- **Docker** - For containerized testing
- **curl/wget** - For network and HTTP operations
- **jq** - For JSON processing (some modules)

## 📄 License

This project is released into the public domain under the [Unlicense](http://unlicense.org/). You are free to use, modify, and distribute this code without any restrictions.

## 👨‍💻 Author

Created by **dolpa** - [Website](https://dolpa.me) | [GitHub](https://github.com/dolpa)

### Connect with the Author
- 🌐 **Blog:** [dolpa.me](https://dolpa.me)
- 📡 **RSS Feed:** [Subscribe via RSS](https://dolpa.me/rss)
- 🐙 **GitHub:** [dolpa on GitHub](https://github.com/dolpa)
- 📘 **Facebook:** [Facebook Page](https://www.facebook.com/dolpa79)
- 🐦 **Twitter (X):** [Twitter Profile](https://x.com/_dolpa)
- 💼 **LinkedIn:** [LinkedIn Profile](https://www.linkedin.com/in/paveldolinin/)
- 👽 **Reddit:** [Reddit Profile](https://www.reddit.com/user/Accomplished_Try_928/)
- 💬 **Telegram:** [Telegram Channel](https://t.me/dolpa_me)
- ▶️ **YouTube:** [YouTube Channel](https://www.youtube.com/c/PavelDolinin)

---

**Enjoy using the Bash Utilities Library!** 🎉

*Remember: Don't panic, and always have your bash utilities with you!* 🛠️
