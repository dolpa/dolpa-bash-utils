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
│   ├── ⚡ exec.sh             # Process execution and management
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
│   ├── ⏰ time.sh             # Time and date utilities
│   ├── 🛠️ utils.sh            # General purpose utilities
│   └── ✅ validation.sh       # Input validation functions
└── 📂 tests/                  # Comprehensive test suite
    ├── 📄 README.md           # Test documentation
    ├── 🧪 test_helper.sh      # Test helper functions
    ├── 🧪 test_ansi.bats      # ANSI formatting tests
    └── 🧪 test_*.bats        # Individual module tests (BATS framework)
```

## ✨ Key Features

- 🎨 **Rich Logging** - Color-coded logging with timestamps and multiple log levels
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
| `BASH_UTILS_LOG_LEVEL` | Set minimum log level | `info` |
| `BASH_UTILS_COLOR` | Enable/disable colors | `auto` |
| `BASH_UTILS_LOG_FILE` | Log to file | `""` |
| `BASH_UTILS_HTTP_TIMEOUT` | Timeout (seconds) for HTTP operations | `10` |

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

#### Text Styles
| Function | Description |
|----------|-------------|
| `ansi_bold <text>` | Print bold text |
| `ansi_italic <text>` | Print italic text |
| `ansi_underline <text>` | Print underlined text |
| `ansi_strikethrough <text>` | Print strikethrough text |

#### Background Colors
| Function | Description |
|----------|-------------|
| `ansi_bg_red <text>` | Print text with red background |
| `ansi_bg_green <text>` | Print text with green background |
| `ansi_bg_blue <text>` | Print text with blue background |

#### Composite Functions
| Function | Description |
|----------|-------------|
| `ansi_success <text>` | Green text with checkmark |
| `ansi_error <text>` | Red text with X mark |
| `ansi_warning <text>` | Yellow text with warning icon |
| `ansi_info <text>` | Blue text with info icon |

#### Utilities
| Function | Description |
|----------|-------------|
| `ansi_strip <text>` | Remove ANSI codes from text |
| `ansi_length <text>` | Get visible text length (excluding ANSI codes) |
| `ansi_reset` | Reset all formatting |
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
| `BASH_UTILS_LOG_LEVEL` | `"INFO"` | Minimum log level (TRACE/DEBUG/INFO/WARNING/ERROR/CRITICAL) |
| `BASH_UTILS_NETWORK_TIMEOUT` | `5` | Network operation timeout in seconds |
| `NO_COLOR` | `unset` | Disable color output when set to `1` |

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
| `log_trace(message...)` | Trace-level logging (debug mode only) | `log_trace "Variable value: $var"` |
| `log_debug(message...)` | Debug-level logging (verbose mode) | `log_debug "Processing file: $file"` |
| `log_info(message...)` | Informational messages | `log_info "✅ Process completed"` |
| `log_success(message...)` | Success messages (green) | `log_success "🎉 Deployment successful"` |
| `log_warning(message...)` | Warning messages (yellow) | `log_warning "⚠️ Deprecated function"` |
| `log_error(message...)` | Error messages (red, to stderr) | `log_error "❌ File not found"` |
| `log_critical(message...)` | Critical errors (red background) | `log_critical "💥 System failure"` |
| `log_header(message...)` | Section headers with borders | `log_header "🚀 Starting Deployment"` |
| `log_section(message...)` | Subsection headers | `log_section "📦 Installing packages"` |
| `log_step(number, message)` | Numbered step indicators | `log_step 1 "Preparing environment"` |

### ✅ Validation Functions

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

### 📁 File Operations

| Function | Description | Example |
|----------|-------------|---------|
| `create_backup(file, [dir], [name])` | Create timestamped backup | `backup=$(create_backup "/etc/config")` |
| `ensure_directory(path, [perms])` | Create directory if missing | `ensure_directory "/var/app/logs" 755` |
| `get_absolute_path(path)` | Get absolute path | `abs_path=$(get_absolute_path "./config")` |
| `get_script_dir()` | Get calling script's directory | `script_dir=$(get_script_dir)` |
| `get_script_name()` | Get calling script's name | `script_name=$(get_script_name)` |

### 📂 Filesystem Operations

| Function | Description | Example |
|----------|-------------|---------|
| `fs_exists(path)` | Check if any filesystem object exists | `fs_exists "/tmp/file" && echo "Exists"` |
| `fs_is_file(path)` | Check if path is a regular file | `fs_is_file "$config" && source "$config"` |
| `fs_is_dir(path)` | Check if path is a directory | `fs_is_dir "$backup_dir" || mkdir -p "$backup_dir"` |
| `fs_is_symlink(path)` | Check if path is a symbolic link | `fs_is_symlink "$link" && echo "Is symlink"` |
| `fs_create_dir(path, [mode])` | Create directory recursively | `fs_create_dir "/var/app/data" 755` |
| `fs_remove(path, [force])` | Remove file or directory | `fs_remove "/tmp/cache" true` |
| `fs_copy(src, dst, [preserve])` | Copy file or directory | `fs_copy "/etc/config" "/backup/config" true` |
| `fs_move(src, dst)` | Move/rename file or directory | `fs_move "/tmp/file" "/var/app/file"` |
| `fs_perm_get(path)` | Get octal permissions | `perms=$(fs_perm_get "/etc/passwd")` |
| `fs_perm_set(path, mode)` | Set octal permissions | `fs_perm_set "/var/app/secret" 600` |

### 🌐 Network Operations

| Function | Description | Example |
|----------|-------------|---------|
| `ping_host(host, [count])` | Ping remote host | `ping_host "google.com" && echo "Online"` |
| `resolve_ip(hostname)` | Resolve hostname to IP | `ip=$(resolve_ip "github.com")` |
| `is_port_open(host, port)` | Check if TCP port is open | `is_port_open "localhost" 80 && echo "Web server running"` |
| `download_file(url, dest)` | Download file from URL | `download_file "$url" "/tmp/download.zip"` |
| `check_url(url)` | Verify URL is reachable | `check_url "$api_endpoint" && echo "API available"` |
| `get_public_ip()` | Get public IP address | `public_ip=$(get_public_ip)` |

### 🌐 HTTP Operations

Lightweight HTTP client wrapper. Prefers `curl`, falls back to `wget`.

| Function | Description | Example |
|----------|-------------|---------|
| `http_get(url)` | GET request; write response body to stdout | `html=$(http_get "https://example.com")` |
| `http_post(url, data)` | POST data; write response body to stdout | `resp=$(http_post "$endpoint" '{"ok":true}')` |
| `http_status(url)` | Print HTTP status code to stdout | `code=$(http_status "https://example.com")` |
| `http_download(url, dest)` | Download URL to a local file path | `http_download "$url" "/tmp/file.bin"` |

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
| `exec_run_with_timeout(timeout, cmd...)` | Run command with timeout | `exec_run_with_timeout 10 curl "$url"` |

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

| Function | Description | Example |
|----------|-------------|---------|
| `str_upper(string)` | Convert to uppercase | `upper=$(str_upper "hello")` |
| `str_lower(string)` | Convert to lowercase | `lower=$(str_lower "HELLO")` |
| `str_title(string)` | Convert to title case | `title=$(str_title "hello world")` |
| `str_length(string)` | Get string length | `len=$(str_length "$text")` |
| `str_trim(string)` | Remove leading/trailing whitespace | `clean=$(str_trim "  text  ")` |
| `str_contains(string, substring)` | Check if string contains substring | `str_contains "$text" "error" && echo "Error found"` |
| `str_replace(string, search, replace)` | Replace all occurrences | `new=$(str_replace "$text" "old" "new")` |
| `str_split(string, delimiter, array_name)` | Split string into array | `str_split "$csv" "," parts` |
| `str_join(delimiter, word...)` | Join words with delimiter | `path=$(str_join "/" "usr" "local" "bin")` |

### 💬 User Interaction

| Function | Description | Example |
|----------|-------------|---------|
| `prompt_input(prompt, [default])` | Get user input | `name=$(prompt_input "Enter name" "default")` |
| `prompt_password(prompt)` | Get password input (hidden) | `pass=$(prompt_password "Enter password")` |
| `prompt_confirm(prompt, [default])` | Get yes/no confirmation | `confirm "Continue?" "y" && echo "Proceeding"` |
| `prompt_menu(title, option...)` | Show selection menu | `choice=$(prompt_menu "Select" "Option 1" "Option 2")` |
| `prompt_number(prompt, [min], [max])` | Get numeric input | `num=$(prompt_number "Enter count" 1 100)` |

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
