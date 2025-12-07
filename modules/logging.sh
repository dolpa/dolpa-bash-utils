#!/bin/bash

#===============================================================================
# Bash Utility Library - Logging Module
#===============================================================================
# Description: Logging functions with different levels and formatting
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: config.sh (for colors and configuration)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_LOGGING_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_LOGGING_LOADED="true"

#===============================================================================
# LOGGING FUNCTIONS
#===============================================================================

# Get current timestamp using configured format
# Uses BASH_UTILS_TIMESTAMP_FORMAT from config.sh
# Returns: formatted timestamp string
_get_timestamp() {
    date +"${BASH_UTILS_TIMESTAMP_FORMAT}"
}

# Internal logging function used by all public log functions
# Formats and outputs log messages with level, color, and optional timestamp
# Arguments:
#   $1 - log level (e.g., INFO, ERROR, DEBUG)
#   $2 - color code for the level
#   $3 - message text to log
_log() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp
    
    timestamp=$(_get_timestamp)
    
    if [[ "${BASH_UTILS_TIMESTAMP:-true}" == "true" ]]; then
        echo -e "${color}[${level}]${COLOR_NC} ${timestamp} - ${message}"
    else
        echo -e "${color}[${level}]${COLOR_NC} ${message}"
    fi
}

# Log trace-level messages (only when debug mode is enabled)
# Used for detailed debugging information
# Usage: log_trace "Entering function with args: $@"
# Arguments: message components (concatenated with spaces)
log_trace() {
    if [[ "${BASH_UTILS_DEBUG}" == "true" ]]; then
        _log "TRACE" "${COLOR_GRAY}" "$*"
    fi
}

# Log debug-level messages (only when verbose or debug mode is enabled)
# Used for troubleshooting and development information
# Usage: log_debug "Variable value: $var_name = $var_value"
# Arguments: message components (concatenated with spaces)
log_debug() {
    if [[ "${BASH_UTILS_VERBOSE}" == "true" ]] || [[ "${BASH_UTILS_DEBUG}" == "true" ]]; then
        _log "DEBUG" "${COLOR_BLUE}" "$*"
    fi
}

# Log informational messages (always displayed)
# Used for general application information and progress updates
# Usage: log_info "Processing file: $filename"
# Arguments: message components (concatenated with spaces)
log_info() {
    _log "INFO" "${COLOR_BLUE}" "$*"
}

# Log success messages (displayed in green)
# Used to indicate successful completion of operations
# Usage: log_success "File saved successfully to $destination"
# Arguments: message components (concatenated with spaces)
log_success() {
    _log "SUCCESS" "${COLOR_GREEN}" "$*"
}

# Log warning messages (displayed in yellow)
# Used to indicate potential issues that don't prevent execution
# Usage: log_warning "Configuration file not found, using defaults"
# Arguments: message components (concatenated with spaces)
log_warning() {
    _log "WARNING" "${COLOR_YELLOW}" "$*"
}

# Alias for log_warning for convenience
log_warn() {
    log_warning "$@"
}

# Log error messages (displayed in red, sent to stderr)
# Used for errors that may prevent successful execution
# Usage: log_error "Failed to read configuration file: $config_path"
# Arguments: message components (concatenated with spaces)
log_error() {
    _log "ERROR" "${COLOR_RED}" "$*" >&2
}

# Log critical error messages (displayed with red background, sent to stderr)
# Used for severe errors that require immediate attention
# Usage: log_critical "System failure: unable to continue execution"
# Arguments: message components (concatenated with spaces)
log_critical() {
    _log "CRITICAL" "${COLOR_BG_RED}${COLOR_WHITE}" "$*" >&2
}

# Alias for log_critical for convenience
log_fatal() {
    log_critical "$@"
}

#===============================================================================
# SPECIAL FORMATTING FUNCTIONS
#===============================================================================

# Create a formatted header with border lines
# Used for major section headers in script output
# Usage: log_header "Application Configuration"
# Arguments: message components (concatenated with spaces)
log_header() {
    local message="$*"
    local line_length=${#message}
    local separator=$(printf '%*s' "$line_length" | tr ' ' '=')
    
    echo -e "${COLOR_BOLD}${COLOR_BLUE}"
    echo "$separator"
    echo "$message"
    echo "$separator"
    echo -e "${COLOR_NC}"
}

# Create a formatted section header
# Used for subsection headers within major sections
# Usage: log_section "Database Configuration"
# Arguments: message components (concatenated with spaces)
log_section() {
    local message="$*"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}### ${message}${COLOR_NC}"
}

# Create a numbered step indicator
# Used for sequential process steps
# Usage: log_step 1 "Initializing configuration"
# Arguments:
#   $1 - step number
#   $2 - step description
log_step() {
    local step_number="$1"
    local message="$2"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}Step ${step_number}:${COLOR_NC} ${message}"
}

# Export all logging functions for use in other scripts
export -f log_trace log_debug log_info log_success log_warning log_warn log_error log_critical log_fatal
export -f log_header log_section log_step