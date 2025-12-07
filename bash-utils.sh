#!/bin/bash

#===============================================================================
# Bash Utility Library - Main Loader
#===============================================================================
# Description: Main entry point that loads all utility modules
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Usage: source this file in your bash scripts to load all utilities
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_LOADED="true"

# Get the directory where this script is located
BASH_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/modules/"

#===============================================================================
# LOAD UTILITY MODULES
#===============================================================================

# Source all utility modules in dependency order
# shellcheck source=./modules/config.sh
source "${BASH_UTILS_DIR}/config.sh"
# shellcheck source=./modules/logging.sh
source "${BASH_UTILS_DIR}/logging.sh"
# shellcheck source=./modules/validation.sh
source "${BASH_UTILS_DIR}/validation.sh"
# shellcheck source=./modules/files.sh
source "${BASH_UTILS_DIR}/files.sh"
# shellcheck source=./modules/system.sh
source "${BASH_UTILS_DIR}/system.sh"
# shellcheck source=./modules/utils.sh
source "${BASH_UTILS_DIR}/utils.sh"
# shellcheck source=./modules/strings.sh
source "${BASH_UTILS_DIR}/strings.sh"
# shellcheck source=./modules/prompts.sh
source "${BASH_UTILS_DIR}/prompts.sh"

#===============================================================================
# LIBRARY INFORMATION
#===============================================================================

# Show library version and information
bash_utils_info() {
    cat << EOF
${BASH_UTILS_NAME} v${BASH_UTILS_VERSION}

Loaded Modules:
  config.sh    - Configuration constants and color definitions
  logging.sh   - Logging functions with different levels
  validation.sh - Input validation and checking functions
  files.sh     - File and directory manipulation functions
  system.sh    - Operating system and hardware detection
  utils.sh     - General utilities, signal handling, version management

Available functions:
  Logging: log_info, log_success, log_warning, log_error, log_debug, log_critical
  Validation: validate_file, validate_directory, validate_system_name, validate_email, validate_url
  System: get_os_name, get_os_version, auto_detect_system, command_exists, is_root, check_privileges
  File operations: create_backup, ensure_directory, get_absolute_path, get_script_dir
  Utilities: confirm, retry, show_spinner, seconds_to_human, bytes_to_human, generate_random_string
  Version comparison: is_semver, compare_versions
  Signal handling: setup_signal_handlers
  
Colors available: COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, etc.
Configuration: Set BASH_UTILS_VERBOSE=true for debug output

For full documentation, see the function definitions in the individual module files.
EOF
}

# Export the info function
export -f bash_utils_info

log_debug "Bash Utility Library v${BASH_UTILS_VERSION} loaded successfully with all modules"