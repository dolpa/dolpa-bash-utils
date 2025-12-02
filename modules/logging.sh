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

# Get current timestamp
_get_timestamp() {
    date +"${BASH_UTILS_TIMESTAMP_FORMAT}"
}

# Internal logging function
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

# Logging functions with different levels
log_trace() {
    if [[ "${BASH_UTILS_DEBUG}" == "true" ]]; then
        _log "TRACE" "${COLOR_GRAY}" "$*"
    fi
}

log_debug() {
    if [[ "${BASH_UTILS_VERBOSE}" == "true" ]] || [[ "${BASH_UTILS_DEBUG}" == "true" ]]; then
        _log "DEBUG" "${COLOR_BLUE}" "$*"
    fi
}

log_info() {
    _log "INFO" "${COLOR_BLUE}" "$*"
}

log_success() {
    _log "SUCCESS" "${COLOR_GREEN}" "$*"
}

log_warning() {
    _log "WARNING" "${COLOR_YELLOW}" "$*"
}

log_warn() {
    log_warning "$@"  # Alias
}

log_error() {
    _log "ERROR" "${COLOR_RED}" "$*" >&2
}

log_critical() {
    _log "CRITICAL" "${COLOR_BG_RED}${COLOR_WHITE}" "$*" >&2
}

log_fatal() {
    log_critical "$@"  # Alias
}

# Special logging functions
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

log_section() {
    local message="$*"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}### ${message}${COLOR_NC}"
}

log_step() {
    local step_number="$1"
    local message="$2"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}Step ${step_number}:${COLOR_NC} ${message}"
}

# Export logging functions
export -f log_trace log_debug log_info log_success log_warning log_warn log_error log_critical log_fatal
export -f log_header log_section log_step