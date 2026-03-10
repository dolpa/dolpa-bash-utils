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

declare -A BASH_UTILS_LOG_LEVEL_MAP=(
    [TRACE]=0
    [DEBUG]=1
    [INFO]=2
    [SUCCESS]=3
    [WARNING]=4
    [ERROR]=5
    [CRITICAL]=6
)

# Normalize configured minimum level once
_BASH_UTILS_LOG_LEVEL_NAME="$(printf '%s' "${BASH_UTILS_LOG_LEVEL:-INFO}" | tr '[:lower:]' '[:upper:]')"
BASH_UTILS_LOG_MIN_LEVEL="${BASH_UTILS_LOG_LEVEL_MAP[$_BASH_UTILS_LOG_LEVEL_NAME]:-2}"

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
    local min_level_num

    local normalized_level
    local level_num
    local normalized_min_level

    normalized_level="$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')"
    level_num="${BASH_UTILS_LOG_LEVEL_MAP[$normalized_level]}"

    echo "min_level_num: $min_level_num, level_num: $level_num" >&2
    if (( level_num < min_level_num )); then
        return 0
    fi

    local timestamp
    timestamp=$(_get_timestamp)

    if [[ "${BASH_UTILS_TIMESTAMP:-true}" == "true" ]]; then
        printf "%b[%s]%b %s - %s\n" "$color" "$level" "$COLOR_NC" "$timestamp" "$message"
    else
        printf "%b[%s]%b %s\n" "$color" "$level" "$COLOR_NC" "$message"
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

# Logging into a file instead of stdout/stderr
# Logs the message to the specified file in addition to standard output
# Arguments:
#   $1 - log level (e.g., INFO, ERROR, DEBUG)
#   $2 - log file path
#   $3 - message text to log
log_to_file() {
    local level
    local log_file
    local normalized_level
    local message
    local timestamp

    level="$1"
    log_file="$2"

    shift 2
    message="$*"
    normalized_level="$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')"

    # Print log to the terminal using the appropriate log function based on the level
    case "$normalized_level" in
        trace)      log_trace "$message" ;;
        debug)      log_debug "$message" ;;
        info)       log_info "$message" ;;
        success)    log_success "$message" ;;
        warning|warn)
                    log_warning "$message" ;;
        error)      log_error "$message" ;;
        critical|fatal)
                    log_critical "$message" ;;
        *)          log_info "$message" ;;
    esac

    # Write the log message to the specified file with timestamp and level
    if [[ -n "$log_file" ]]; then
        timestamp=$(_get_timestamp)
        if [[ "${BASH_UTILS_TIMESTAMP:-true}" == "true" ]]; then
            printf '[%s] %s - %s\n' "$(printf '%s' "$normalized_level" | tr '[:lower:]' '[:upper:]')" "$timestamp" "$message" >> "$log_file"
        else
            printf '[%s] %s\n' "$(printf '%s' "$normalized_level" | tr '[:lower:]' '[:upper:]')" "$message" >> "$log_file"
        fi
    fi
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
    
    printf "%b\n%s\n%s\n%s\n%b" \
        "$COLOR_BOLD$COLOR_BLUE" \
        "$separator" \
        "$message" \
        "$separator" \
        "$COLOR_NC"
}

# Create a formatted section header
# Used for subsection headers within major sections
# Usage: log_section "Database Configuration"
# Arguments: message components (concatenated with spaces)
log_section() {
    local message="$*"
    printf "${COLOR_BOLD}${COLOR_CYAN}### %s${COLOR_NC}\n" "$message"
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
    printf "${COLOR_BOLD}${COLOR_GREEN}Step %s:${COLOR_NC} %s\n" "$step_number" "$message"
}

# Export all logging functions for use in other scripts
export -f log_trace log_debug log_info log_success log_warning log_warn log_error log_critical log_fatal log_to_file
export -f log_header log_section log_step