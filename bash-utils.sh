#!/bin/bash

#===============================================================================
# Bash Utility Library - Main Loader
#===============================================================================
# Description: Main entry point that loads all utility modules
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# 
# Modules included:
# - applications.sh: Application installation and management utilities
# - config.sh: Color definitions and configuration
# - logging.sh: Comprehensive logging with levels and colors
# - validation.sh: Input validation and sanitization
# - files.sh: File backup and management utilities
# - filesystem.sh: Comprehensive filesystem operations and path analysis
# - network.sh: Network utilities for connectivity and file transfers
# - system.sh: System detection and hardware information
# - utils.sh: General utilities, retry logic, formatters
# - strings.sh: String manipulation and text processing
# - prompts.sh: Interactive user input and menus
# - exec.sh: Process execution, background jobs, and timeout handling
#
# Usage: source this file in your bash scripts to load all utilities
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_LOADED="true"

# Determine script location and module directory paths
# This allows the library to work regardless of where it's sourced from
BASH_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_UTILS_MODULES_DIR="${BASH_UTILS_DIR}/modules"

#===============================================================================
# LOAD UTILITY MODULES
#===============================================================================

# Load all utility modules in proper dependency order
# Each module checks for previous loading to prevent conflicts
# Dependencies: config -> logging -> validation -> files/filesystem/network/system/utils -> strings/prompts -> exec -> applications
# 
# Module descriptions:
# - config.sh: Core configuration and color definitions
# - logging.sh: Logging framework with multiple levels
# - validation.sh: Input validation and type checking
# - files.sh: File backup and management operations
# - filesystem.sh: Comprehensive filesystem operations, path analysis, and file manipulation
# - network.sh: Network utilities for connectivity, resolution, and file transfers
# - system.sh: System detection and hardware information gathering
# - utils.sh: General purpose utilities and helper functions
# - strings.sh: String processing, manipulation, and formatting
# - prompts.sh: Interactive user input, confirmations, and menus
# - exec.sh: Process execution, background job management, and timeout handling
# - applications.sh: Application installation and management across Linux distributions
# - env.sh: Environment variable management and validation
#===============================================================================
# shellcheck source=./modules/config.sh
source "${BASH_UTILS_MODULES_DIR}/config.sh"
# shellcheck source=./modules/logging.sh
source "${BASH_UTILS_MODULES_DIR}/logging.sh"
# shellcheck source=./modules/validation.sh
source "${BASH_UTILS_MODULES_DIR}/validation.sh"
# shellcheck source=./modules/files.sh
source "${BASH_UTILS_MODULES_DIR}/files.sh"
# shellcheck source=./modules/filesystem.sh
source "${BASH_UTILS_MODULES_DIR}/filesystem.sh"
# shellcheck source=./modules/system.sh
source "${BASH_UTILS_MODULES_DIR}/system.sh"
# shellcheck source=./modules/utils.sh
source "${BASH_UTILS_MODULES_DIR}/utils.sh"
# shellcheck source=./modules/strings.sh
source "${BASH_UTILS_MODULES_DIR}/strings.sh"
# shellcheck source=./modules/prompts.sh
source "${BASH_UTILS_MODULES_DIR}/prompts.sh"
# shellcheck source=./modules/exec.sh
source "${BASH_UTILS_MODULES_DIR}/exec.sh"
# shellcheck source=./modules/applications.sh
source "${BASH_UTILS_MODULES_DIR}/applications.sh"
# shellcheck source=./modules/network.sh
source "${BASH_UTILS_MODULES_DIR}/network.sh"
# shellcheck source=./modules/env.sh
source "${BASH_UTILS_MODULES_DIR}/env.sh"
# shellcheck source=./modules/args.sh
source "${BASH_UTILS_MODULES_DIR}/args.sh"
# shellcheck source=./modules/services.sh
source "${BASH_UTILS_MODULES_DIR}/services.sh"
# shellcheck source=./modules/packages.sh
source "${BASH_UTILS_MODULES_DIR}/packages.sh"
# shellcheck source=./modules/crypto.sh
source "${BASH_UTILS_MODULES_DIR}/crypto.sh"

#===============================================================================
# LIBRARY INFORMATION
#===============================================================================

# Show library version and information
bash_utils_info() {
    cat << EOF
${BASH_UTILS_NAME} v${BASH_UTILS_VERSION}

Loaded Modules:
  applications.sh - Application installation and management utilities
  config.sh      - Configuration constants and color definitions
  logging.sh     - Logging functions with different levels and formatting
  validation.sh  - Input validation and system checking functions
  files.sh       - File and directory manipulation utilities
  filesystem.sh  - Comprehensive filesystem operations and path analysis
  network.sh     - Network utilities for connectivity and file transfers
  system.sh      - Operating system and hardware detection
  utils.sh       - General utilities, signal handling, version management
  strings.sh     - String manipulation and text processing utilities
  prompts.sh     - User input and interaction functions
  exec.sh        - Process execution and background job management
  env.sh         - Environment variable management and validation
  args.sh        - Command-line argument parsing and handling
  services.sh    - Service management across different init systems
  packages.sh    - Package manager detection and application installation
  crypto.sh      - Hashing, checksums, and key generation utilities

Available Functions:
  Logging: log_info, log_success, log_warning, log_error, log_debug, log_critical
  Validation: validate_file, validate_directory, validate_system_name, validate_email, validate_url
  System: get_os_name, get_os_version, auto_detect_system, command_exists, is_root, check_privileges
  File Operations: create_backup, ensure_directory, get_absolute_path, get_script_dir
  Applications: app_is_installed, app_install_docker, app_remove_docker
  Utilities: confirm, retry, show_spinner, seconds_to_human, bytes_to_human, generate_random_string
  Version: is_semver, compare_versions
  Signal Handling: setup_signal_handlers
  String Operations: str_upper, str_lower, str_trim, str_contains, str_replace, str_split, str_join
  User Prompts: prompt_input, prompt_password, prompt_confirm, prompt_menu, prompt_number range
  Process Execution: exec_cmd, exec_cmd_bg, exec_with_timeout
  Environment: env_set, env_get, env_require, env_load_file
  Services: service_start, service_stop, service_restart, service_status, service_enable, service_disable
  Packages: pkg_detect_manager, pkg_install, pkg_remove, pkg_update, pkg_installed
  Crypto: hash_sha256, hash_verify, uuid_generate, random_string

  
Colors: COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, COLOR_PURPLE, COLOR_CYAN, etc.
Configuration: Set BASH_UTILS_VERBOSE=true for verbose output, BASH_UTILS_DEBUG=true for debug

For comprehensive documentation, see function definitions in individual module files.
EOF
}

# Make the info function available to calling scripts
export -f bash_utils_info

# Log successful library loading (only in debug/verbose mode)
log_debug "Bash Utility Library v${BASH_UTILS_VERSION} loaded successfully with all modules"