#!/bin/bash

#===============================================================================
# Bash Utility Library - Validation Module
#===============================================================================
# Description: Input validation and checking functions
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for error logging)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_VALIDATION_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_VALIDATION_LOADED="true"

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

# Check if a command is available in the system PATH
# Usage: if command_exists "git"; then ...; fi
# Arguments:
#   $1 - command name to check
# Returns: 0 if command exists, 1 otherwise
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check if the current user is root (UID 0)
# Usage: if is_root; then ...; fi
# Returns: 0 if running as root, 1 otherwise
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if the script is running under sudo
# Usage: if is_sudo; then ...; fi
# Returns: 0 if running under sudo, 1 otherwise
is_sudo() {
    [[ -n "${SUDO_USER:-}" ]]
}

# Ensure the script is running with root or sudo privileges
# Displays error message and returns failure if insufficient privileges
# Usage: check_privileges "Database operations require root access"
# Arguments:
#   $1 - optional custom error message
# Returns: 0 if running with privileges, 1 otherwise
check_privileges() {
    local error_message="${1:-This operation requires root privileges}"
    
    if ! is_root && ! is_sudo; then
        log_error "$error_message"
        log_error "Please run with sudo or as root user"
        return 1
    fi
    
    return 0
}

# Validate that a specified file exists and is readable
# Logs error message if file doesn't exist
# Usage: validate_file "/etc/hosts" "System hosts file"
# Arguments:
#   $1 - file path to validate
#   $2 - optional description for error messages (default: "File")
# Returns: 0 if file exists, 1 otherwise
validate_file() {
    local file="$1"
    local description="${2:-File}"
    
    if [[ ! -f "$file" ]]; then
        log_error "$description not found: $file"
        return 1
    fi
    
    return 0
}

# Validate that a specified directory exists and is accessible
# Logs error message if directory doesn't exist
# Usage: validate_directory "/var/log" "Log directory"
# Arguments:
#   $1 - directory path to validate
#   $2 - optional description for error messages (default: "Directory")
# Returns: 0 if directory exists, 1 otherwise
validate_directory() {
    local dir="$1"
    local description="${2:-Directory}"
    
    if [[ ! -d "$dir" ]]; then
        log_error "$description not found: $dir"
        return 1
    fi
    
    return 0
}

# Validate that a variable contains a non-empty value
# Logs error message if variable is empty or unset
# Usage: validate_not_empty "$username" "Username"
# Arguments:
#   $1 - variable value to check
#   $2 - optional variable name for error messages (default: "Variable")
# Returns: 0 if variable is not empty, 1 otherwise
validate_not_empty() {
    local var="$1"
    local var_name="${2:-Variable}"
    
    if [[ -z "$var" ]]; then
        log_error "$var_name cannot be empty"
        return 1
    fi
    
    return 0
}

# Validate system name format (hostname-compatible naming)
# Accepts alphanumeric characters, hyphens, and underscores
# Must start and end with alphanumeric characters
# Usage: validate_system_name "web-server-01"
# Arguments:
#   $1 - system name to validate
# Returns: 0 if name is valid, 1 otherwise
validate_system_name() {
    local system_name="$1"
    local pattern="^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$"
    
    if [[ ! "$system_name" =~ $pattern ]]; then
        log_error "Invalid system name: '$system_name'"
        log_error "System name must contain only letters, numbers, hyphens, and underscores"
        log_error "Must start and end with alphanumeric characters"
        return 1
    fi
    
    return 0
}

# Validate email address format using regex pattern
# Checks for basic email structure: user@domain.tld
# Usage: validate_email "user@example.com"
# Arguments:
#   $1 - email address to validate
# Returns: 0 if email format is valid, 1 otherwise
validate_email() {
    local email="$1"
    local pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ ! "$email" =~ $pattern ]]; then
        log_error "Invalid email format: '$email'"
        return 1
    fi
    
    return 0
}

# Validate URL format for HTTP/HTTPS URLs
# Checks for proper protocol and domain structure
# Usage: validate_url "https://example.com/path"
# Arguments:
#   $1 - URL to validate
# Returns: 0 if URL format is valid, 1 otherwise
validate_url() {
    local url="$1"
    # Accept:
    #   - Domain names: https://example.com[/path]
    #   - localhost: http://localhost[:port][/path]
    #   - IPv4: http://10.0.0.1[:port][/path]
    local pattern="^https?://((([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})|localhost|([0-9]{1,3}\.){3}[0-9]{1,3})(:[0-9]{1,5})?(/.*)?$"
    
    if [[ ! "$url" =~ $pattern ]]; then
        log_error "Invalid URL format: '$url'"
        return 1
    fi
    
    return 0
}

# Validate network port number (1-65535)
# Ensures port is numeric and within valid range
# Usage: validate_port "8080"
# Arguments:
#   $1 - port number to validate
# Returns: 0 if port is valid, 1 otherwise
validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "Invalid port number: '$port' (must be 1-65535)"
        return 1
    fi
    
    return 0
}

# Export all validation functions for use in other scripts
export -f command_exists is_root is_sudo check_privileges
export -f validate_file validate_directory validate_not_empty validate_system_name validate_email validate_url validate_port