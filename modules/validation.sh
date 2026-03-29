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

#===============================================================================
# NETWORK VALIDATION FUNCTIONS  
#===============================================================================

# Validate IPv4 address format
# Usage: validate_ipv4 "192.168.1.1" "Server IP"
# Arguments:
#   $1 - IP address to validate
#   $2 - optional description for error messages (default: "IPv4 address")
# Returns: 0 if valid IPv4, 1 otherwise
validate_ipv4() {
    local ip="$1"
    local description="${2:-IPv4 address}"
    
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ "$ip" =~ $regex ]]; then
        local IFS='.'
        local -a parts=($ip)
        local part
        for part in "${parts[@]}"; do
            if [[ $part -gt 255 ]] || [[ ${part#0} != $part && $part != 0 ]]; then
                log_error "Invalid $description: $ip"
                return 1
            fi
        done
        return 0
    fi
    
    log_error "Invalid $description format: $ip"
    return 1
}

# Validate IPv6 address format (basic validation)
# Usage: validate_ipv6 "2001:0db8:85a3:0000:0000:8a2e:0370:7334" "Server IPv6"
# Arguments:
#   $1 - IP address to validate  
#   $2 - optional description for error messages (default: "IPv6 address")
# Returns: 0 if valid IPv6, 1 otherwise
validate_ipv6() {
    local ip="$1"
    local description="${2:-IPv6 address}"
    
    # Basic IPv6 regex pattern
    local regex="^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"
    
    if [[ "$ip" =~ $regex ]]; then
        return 0
    fi
    
    log_error "Invalid $description format: $ip"
    return 1
}

# Validate MAC address format  
# Usage: validate_mac_address "00:1B:44:11:3A:B7" "Network interface MAC"
# Arguments:
#   $1 - MAC address to validate
#   $2 - optional description for error messages (default: "MAC address")
# Returns: 0 if valid MAC address, 1 otherwise
validate_mac_address() {
    local mac="$1"
    local description="${2:-MAC address}"
    
    local regex="^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$"
    
    if [[ "$mac" =~ $regex ]]; then
        return 0
    fi
    
    log_error "Invalid $description format: $mac"
    return 1
}

#===============================================================================
# DATA FORMAT VALIDATION FUNCTIONS
#===============================================================================

# Validate date format (YYYY-MM-DD)
# Usage: validate_date "2023-12-25" "Due date"
# Arguments:
#   $1 - date to validate
#   $2 - optional description for error messages (default: "Date")
# Returns: 0 if valid date, 1 otherwise
validate_date() {
    local date_str="$1"
    local description="${2:-Date}"
    
    local regex="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    
    if [[ ! "$date_str" =~ $regex ]]; then
        log_error "Invalid $description format (expected YYYY-MM-DD): $date_str"
        return 1
    fi
    
    # Extract year, month, day
    local year="${date_str:0:4}"
    local month="${date_str:5:2}"
    local day="${date_str:8:2}"
    
    # Basic range validation
    if [[ $month -lt 1 || $month -gt 12 ]]; then
        log_error "Invalid month in $description: $month"
        return 1
    fi
    
    if [[ $day -lt 1 || $day -gt 31 ]]; then
        log_error "Invalid day in $description: $day"
        return 1
    fi
    
    return 0
}

# Validate phone number (basic US format)
# Usage: validate_phone_number "555-123-4567" "Contact number"
# Arguments:
#   $1 - phone number to validate
#   $2 - optional description for error messages (default: "Phone number")
# Returns: 0 if valid phone number, 1 otherwise
validate_phone_number() {
    local phone="$1"
    local description="${2:-Phone number}"
    
    # Support formats: XXX-XXX-XXXX, (XXX) XXX-XXXX, XXX.XXX.XXXX, XXXXXXXXXX
    local regex="^(\([0-9]{3}\) ?|[0-9]{3}[-.]?)[0-9]{3}[-.]?[0-9]{4}$"
    
    if [[ "$phone" =~ $regex ]]; then
        return 0
    fi
    
    log_error "Invalid $description format: $phone"
    return 1
}

# Validate JSON string format (basic)
# Usage: validate_json '{"key": "value"}' "Configuration JSON"
# Arguments:
#   $1 - JSON string to validate
#   $2 - optional description for error messages (default: "JSON")
# Returns: 0 if valid JSON, 1 otherwise
validate_json() {
    local json_str="$1"
    local description="${2:-JSON}"
    
    if command_exists "jq"; then
        if echo "$json_str" | jq . >/dev/null 2>&1; then
            return 0
        fi
    elif command_exists "python3"; then
        if echo "$json_str" | python3 -c "import sys, json; json.load(sys.stdin)" >/dev/null 2>&1; then
            return 0
        fi
    elif command_exists "python"; then
        if echo "$json_str" | python -c "import sys, json; json.load(sys.stdin)" >/dev/null 2>&1; then
            return 0
        fi
    else
        # Basic JSON format check (very primitive)
        if [[ "$json_str" =~ ^\{.*\}$|^\[.*\]$ ]]; then
            return 0
        fi
    fi
    
    log_error "Invalid $description format: $json_str"
    return 1
}

#===============================================================================
# NUMERIC VALIDATION FUNCTIONS
#===============================================================================

# Validate number is within specified range
# Usage: validate_number_range "15" 1 100 "Age"
# Arguments:
#   $1 - number to validate
#   $2 - minimum value (inclusive)
#   $3 - maximum value (inclusive)
#   $4 - optional description for error messages (default: "Number")
# Returns: 0 if within range, 1 otherwise
validate_number_range() {
    local number="$1"
    local min="$2"
    local max="$3"
    local description="${4:-Number}"
    
    if [[ ! "$number" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "$description must be a valid number: $number"
        return 1
    fi
    
    if command_exists "bc"; then
        if (( $(echo "$number < $min" | bc -l) )) || (( $(echo "$number > $max" | bc -l) )); then
            log_error "$description must be between $min and $max: $number"
            return 1
        fi
    else
        # Integer-only fallback if bc is not available
        if [[ $number -lt $min ]] || [[ $number -gt $max ]]; then
            log_error "$description must be between $min and $max: $number"
            return 1
        fi
    fi
    
    return 0
}

# Validate that a number is positive
# Usage: validate_positive_number "42" "Count value"
# Arguments:
#   $1 - number to validate
#   $2 - optional description for error messages (default: "Number")
# Returns: 0 if positive, 1 otherwise
validate_positive_number() {
    local number="$1"
    local description="${2:-Number}"
    
    if [[ ! "$number" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        log_error "$description must be a valid positive number: $number"
        return 1
    fi
    
    if command_exists "bc"; then
        if (( $(echo "$number <= 0" | bc -l) )); then
            log_error "$description must be positive: $number"
            return 1
        fi
    else
        # Integer-only fallback
        if [[ $number -le 0 ]]; then
            log_error "$description must be positive: $number"
            return 1
        fi
    fi
    
    return 0
}

#===============================================================================
# SYSTEM VALIDATION FUNCTIONS
#===============================================================================

# Validate that a process is running
# Usage: validate_process_running "nginx" "Web server"
# Arguments:
#   $1 - process name or PID to check
#   $2 - optional description for error messages (default: "Process")
# Returns: 0 if process running, 1 otherwise
validate_process_running() {
    local process="$1"
    local description="${2:-Process}"
    
    if [[ "$process" =~ ^[0-9]+$ ]]; then
        # Check by PID
        if kill -0 "$process" 2>/dev/null; then
            return 0
        fi
    else
        # Check by process name
        if pgrep -f "$process" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    log_error "$description '$process' is not running"
    return 1
}

# Validate available disk space
# Usage: validate_disk_space "/tmp" 1024 "Temporary directory"
# Arguments:
#   $1 - path to check
#   $2 - minimum required space in MB
#   $3 - optional description for error messages (default: "Path")
# Returns: 0 if enough space available, 1 otherwise
validate_disk_space() {
    local path="$1"
    local required_mb="$2"
    local description="${3:-Path}"
    
    if [[ ! -d "$path" ]]; then
        log_error "Cannot check disk space: $description '$path' does not exist"
        return 1
    fi
    
    local available_kb
    available_kb=$(df -k "$path" | awk 'NR==2 {print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [[ $available_mb -lt $required_mb ]]; then
        log_error "Insufficient disk space in $description '$path': ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    
    return 0
}

# Validate username format (alphanumeric, underscore, dash, 3-32 chars)
# Usage: validate_username "john_doe" "User account"
# Arguments:
#   $1 - username to validate
#   $2 - optional description for error messages (default: "Username")
# Returns: 0 if valid username, 1 otherwise
validate_username() {
    local username="$1"
    local description="${2:-Username}"
    
    local regex="^[a-zA-Z0-9_-]{3,32}$"
    
    if [[ "$username" =~ $regex ]]; then
        return 0
    fi
    
    log_error "Invalid $description format (3-32 alphanumeric chars, underscore, dash): $username"
    return 1
}

# Validate password strength (basic criteria)
# Usage: validate_password_strength "MyP@ssw0rd123" "User password"
# Arguments:
#   $1 - password to validate
#   $2 - optional description for error messages (default: "Password")
# Returns: 0 if meets criteria, 1 otherwise
validate_password_strength() {
    local password="$1"
    local description="${2:-Password}"
    
    local length=${#password}
    local errors=()
    
    # Check minimum length
    if [[ $length -lt 8 ]]; then
        errors+=("must be at least 8 characters long")
    fi
    
    # Check for uppercase letter
    if [[ ! "$password" =~ [A-Z] ]]; then
        errors+=("must contain at least one uppercase letter")
    fi
    
    # Check for lowercase letter
    if [[ ! "$password" =~ [a-z] ]]; then
        errors+=("must contain at least one lowercase letter")
    fi
    
    # Check for digit
    if [[ ! "$password" =~ [0-9] ]]; then
        errors+=("must contain at least one digit")
    fi
    
    # Check for special character
    if [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        errors+=("must contain at least one special character")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        local IFS=', '
        log_error "$description ${errors[*]}"
        return 1
    fi
    
    return 0
}

# Validate environment variable is set and not empty
# Usage: validate_env_var "HOME" "Home directory"
# Arguments:
#   $1 - environment variable name
#   $2 - optional description for error messages (default: variable name)
# Returns: 0 if set and not empty, 1 otherwise
validate_env_var() {
    local var_name="$1"
    local description="${2:-$var_name}"
    
    if [[ -z "${!var_name:-}" ]]; then
        log_error "Environment variable '$description' is not set or empty"
        return 1
    fi
    
    return 0
}

# Export all validation functions for use in other scripts
export -f command_exists is_root is_sudo check_privileges
export -f validate_file validate_directory validate_not_empty validate_system_name validate_email validate_url validate_port
export -f validate_ipv4 validate_ipv6 validate_mac_address
export -f validate_date validate_phone_number validate_json
export -f validate_number_range validate_positive_number
export -f validate_process_running validate_disk_space validate_username validate_password_strength validate_env_var