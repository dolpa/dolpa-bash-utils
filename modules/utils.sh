#!/bin/bash

#===============================================================================
# Bash Utility Library - Utilities Module
#===============================================================================
# Description: General utility functions, signal handling, and version management
# Author: dolpa
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for logging), config.sh (for colors)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_UTILITIES_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_UTILITIES_LOADED="true"

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Show a spinner while running a command
show_spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local delay=0.1
    
    echo -n "$message "
    
    while kill -0 "$pid" 2>/dev/null; do
        for ((i=0; i<${#spinner_chars}; i++)); do
            echo -ne "\b${spinner_chars:$i:1}"
            sleep "$delay"
            if ! kill -0 "$pid" 2>/dev/null; then
                break 2
            fi
        done
    done
    
    echo -ne "\b✓\n"
}

# Ask for user confirmation
confirm() {
    local message="${1:-Are you sure?}"
    local default="${2:-n}"
    local prompt
    
    if [[ "$default" =~ ^[Yy] ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    echo -ne "${COLOR_YELLOW}${message} ${prompt}: ${COLOR_NC}"
    read -r response
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    if [[ "$response" =~ ^[Yy] ]]; then
        return 0
    else
        return 1
    fi
}

# Retry a command with exponential backoff
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local max_delay="${3:-60}"
    shift 3
    local cmd=("$@")
    
    local attempt=1
    local current_delay="$delay"
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: ${cmd[*]}"
        
        if "${cmd[@]}"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Command failed, retrying in ${current_delay}s..."
            sleep "$current_delay"
            current_delay=$(( current_delay * 2 ))
            if [[ $current_delay -gt $max_delay ]]; then
                current_delay="$max_delay"
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts: ${cmd[*]}"
    return 1
}

# Convert seconds to human readable format
seconds_to_human() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    local result=""
    
    if [[ $days -gt 0 ]]; then
        result="${days}d "
    fi
    
    if [[ $hours -gt 0 ]]; then
        result="${result}${hours}h "
    fi
    
    if [[ $minutes -gt 0 ]]; then
        result="${result}${minutes}m "
    fi
    
    if [[ $secs -gt 0 ]] || [[ -z "$result" ]]; then
        result="${result}${secs}s"
    fi
    
    echo "${result// /}"
}

# Convert bytes to human readable format
bytes_to_human() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit_index=0
    local size="$bytes"
    
    while [[ $size -ge 1024 && $unit_index -lt $((${#units[@]} - 1)) ]]; do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    echo "${size}${units[$unit_index]}"
}

# Generate a random string
generate_random_string() {
    local length="${1:-16}"
    local chars="${2:-a-zA-Z0-9}"
    
    tr -dc "$chars" < /dev/urandom | head -c "$length"
    echo
}

# Check if a string is a valid semver
is_semver() {
    local version="$1"
    local pattern="^([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"
    
    [[ "$version" =~ $pattern ]]
}

# Compare two semantic versions
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$version1" == "$version2" ]]; then
        echo "0"
        return
    fi
    
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    # Fill empty fields with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            echo "1"
            return
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            echo "-1"
            return
        fi
    done
    
    echo "0"
}

#===============================================================================
# SIGNAL HANDLING
#===============================================================================

# Set up common signal handlers
setup_signal_handlers() {
    local cleanup_function="${1:-cleanup_on_exit}"
    
    trap "$cleanup_function" EXIT
    trap 'log_error "Script interrupted by user"; exit 130' INT TERM
}

# Default cleanup function (can be overridden)
cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "Script completed successfully"
    else
        log_error "Script exited with code: $exit_code"
    fi
}

# Export utility functions
export -f show_spinner confirm retry seconds_to_human bytes_to_human generate_random_string
export -f is_semver compare_versions
export -f setup_signal_handlers cleanup_on_exit