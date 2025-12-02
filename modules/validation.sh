#!/bin/bash

#===============================================================================
# Bash Utility Library - Validation Module
#===============================================================================
# Description: Input validation and checking functions
# Author: dolpa
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

# Check if a command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if running with sudo
is_sudo() {
    [[ -n "${SUDO_USER:-}" ]]
}

# Check if running as root or with sudo
check_privileges() {
    local error_message="${1:-This operation requires root privileges}"
    
    if ! is_root && ! is_sudo; then
        log_error "$error_message"
        log_error "Please run with sudo or as root user"
        return 1
    fi
    
    return 0
}

# Validate that a file exists
validate_file() {
    local file="$1"
    local description="${2:-File}"
    
    if [[ ! -f "$file" ]]; then
        log_error "$description not found: $file"
        return 1
    fi
    
    return 0
}

# Validate that a directory exists
validate_directory() {
    local dir="$1"
    local description="${2:-Directory}"
    
    if [[ ! -d "$dir" ]]; then
        log_error "$description not found: $dir"
        return 1
    fi
    
    return 0
}

# Validate that a variable is not empty
validate_not_empty() {
    local var="$1"
    local var_name="${2:-Variable}"
    
    if [[ -z "$var" ]]; then
        log_error "$var_name cannot be empty"
        return 1
    fi
    
    return 0
}

# Validate system name format (alphanumeric, hyphens, underscores)
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

# Validate email format
validate_email() {
    local email="$1"
    local pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ ! "$email" =~ $pattern ]]; then
        log_error "Invalid email format: '$email'"
        return 1
    fi
    
    return 0
}

# Validate URL format
validate_url() {
    local url="$1"
    local pattern="^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$"
    
    if [[ ! "$url" =~ $pattern ]]; then
        log_error "Invalid URL format: '$url'"
        return 1
    fi
    
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "Invalid port number: '$port' (must be 1-65535)"
        return 1
    fi
    
    return 0
}

# Export validation functions
export -f command_exists is_root is_sudo check_privileges
export -f validate_file validate_directory validate_not_empty validate_system_name validate_email validate_url validate_port