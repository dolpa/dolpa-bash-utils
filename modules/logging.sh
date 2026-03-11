#!/usr/bin/env bash

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

# --------------------------------------------------------------------
# Helper: return the numeric value of the *current* configured level.
# This function is called **every time a message is emitted**, so a
# later change of BASH_UTILS_LOG_LEVEL is honoured.
# --------------------------------------------------------------------
_log_configured_level() {
    local cfg_level="${BASH_UTILS_LOG_LEVEL:-INFO}"     # fall back to INFO
    cfg_level=${cfg_level^^}                                 # upper‑case (bash ≥4)
    printf '%d' "${BASH_UTILS_LOG_LEVEL_MAP[$cfg_level]:-2}"
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

    # Normalise the level name to upper‑case (bash 4+ supports ${var^^})
    local _normalized_lvl
    local lvl_num
    # Upper‑case the level for consistent mapping and display
    _normalized_lvl="${level^^}"
    # Numeric severity of the *requested* message
    lvl_num="${BASH_UTILS_LOG_LEVEL_MAP[$_normalized_lvl]:-2}"

    # Numeric severity of the *configured* threshold
    local cfg_num
    cfg_num=$(_log_configured_level)

    # Skip messages below configured level
    if (( lvl_num < cfg_num )); then
        return 0
    fi

    local timestamp
    timestamp=$(_get_timestamp)

    if [[ "${BASH_UTILS_TIMESTAMP:-true}" == "true" ]]; then
        printf "%b[%s]%b %s - %s\n" \
            "$color" "$_normalized_lvl" "${COLOR_NC:-}" "$timestamp" "$message"
    else
        printf "%b[%s]%b %s\n" \
            "$color" "$_normalized_lvl" "${COLOR_NC:-}" "$message"
    fi
}

# Public functions for different log levels
log_trace() {
    [[ "${BASH_UTILS_DEBUG:-false}" == "true" ]] && \
        _log "TRACE" "${COLOR_GRAY:-}" "$*"
}

log_debug() {
    if [[ "${BASH_UTILS_VERBOSE:-false}" == "true" ]] || \
       [[ "${BASH_UTILS_DEBUG:-false}" == "true" ]]; then
        _log "DEBUG" "${COLOR_BLUE:-}" "$*"
    fi
}

log_info() {
    _log "INFO" "${COLOR_BLUE:-}" "$*"
}

log_success() {
    _log "SUCCESS" "${COLOR_GREEN:-}" "$*"
}

log_warning() {
    _log "WARNING" "${COLOR_YELLOW:-}" "$*"
}

log_warn() {
    log_warning "$@"
}

log_error() {
    _log "ERROR" "${COLOR_RED:-}" "$*" >&2
}

log_critical() {
    _log "CRITICAL" "${COLOR_BG_RED:-}${COLOR_WHITE:-}" "$*" >&2
}

log_fatal() {
    log_critical "$@"
}

#===============================================================================
# FILE LOGGING
#===============================================================================

# Logs both to terminal and file
log_to_file() {
    local level="$1"
    local log_file="$2"

    shift 2
    local message="$*"

    local normalized_level
    normalized_level="$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')"

    # Print to terminal
    case "$normalized_level" in
        trace) log_trace "$message" ;;
        debug) log_debug "$message" ;;
        info) log_info "$message" ;;
        success) log_success "$message" ;;
        warning|warn) log_warning "$message" ;;
        error) log_error "$message" ;;
        critical|fatal) log_critical "$message" ;;
        *) log_info "$message" ;;
    esac

    # Write to file
    if [[ -n "$log_file" ]]; then
        local timestamp
        timestamp=$(_get_timestamp)

        local level_upper
        level_upper="$(printf '%s' "$normalized_level" | tr '[:lower:]' '[:upper:]')"

        if [[ "${BASH_UTILS_TIMESTAMP:-true}" == "true" ]]; then
            printf '[%s] %s - %s\n' "$level_upper" "$timestamp" "$message" >> "$log_file"
        else
            printf '[%s] %s\n' "$level_upper" "$message" >> "$log_file"
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
    local separator
    separator=$(printf '%*s' "$line_length" | tr ' ' '=')

    printf "%b\n%s\n%s\n%s\n%b\n" \
        "${COLOR_BOLD:-}${COLOR_BLUE:-}" \
        "$separator" \
        "$message" \
        "$separator" \
        "${COLOR_NC:-}"
}

# Create a formatted section header
# Used for subsection headers within major sections
# Usage: log_section "Database Configuration"
# Arguments: message components (concatenated with spaces)
log_section() {
    printf "%b### %s%b\n" \
        "${COLOR_BOLD:-}${COLOR_CYAN:-}" \
        "$*" \
        "${COLOR_NC:-}"
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

    printf "%bStep %s:%b %s\n" \
        "${COLOR_BOLD:-}${COLOR_GREEN:-}" \
        "$step_number" \
        "${COLOR_NC:-}" \
        "$message"
}

#===============================================================================
# EXPORT FUNCTIONS
#===============================================================================

export -f log_trace log_debug log_info log_success log_warning log_warn
export -f log_error log_critical log_fatal log_to_file
export -f log_header log_section log_step