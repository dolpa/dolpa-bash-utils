#!/bin/bash

#===============================================================================
# Bash Utility Library - System Detection Module
#===============================================================================
# Description: Operating system and hardware detection functions
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for logging), validation.sh (for command_exists)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_SYSTEM_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_SYSTEM_LOADED="true"

#===============================================================================
# SYSTEM DETECTION FUNCTIONS
#===============================================================================

# Get operating system name
get_os_name() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$NAME"
    elif command_exists lsb_release; then
        lsb_release -si
    elif [[ -f /etc/redhat-release ]]; then
        cat /etc/redhat-release
    else
        uname -s
    fi
}

# Get operating system version
get_os_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_ID"
    elif command_exists lsb_release; then
        lsb_release -sr
    else
        uname -r
    fi
}

# Auto-detect system type based on DMI information
auto_detect_system() {
    local detected_system=""
    
    log_debug "Attempting to auto-detect system type..."
    
    # Try to get system information from DMI
    if command_exists dmidecode; then
        local vendor product
        vendor=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' || echo "unknown")
        product=$(dmidecode -s system-product-name 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' || echo "unknown")
        
        # Construct system name from vendor and product
        if [[ "$vendor" != "unknown" && "$product" != "unknown" ]]; then
            detected_system="${vendor}-${product}"
            detected_system=$(echo "$detected_system" | sed 's/[^a-zA-Z0-9_-]//g')
            log_debug "Auto-detected system from DMI: $detected_system"
        fi
    fi
    
    # Fallback detection methods
    if [[ -z "$detected_system" && -f /sys/class/dmi/id/product_name ]]; then
        local product_name
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-zA-Z0-9_-]//g')
        if [[ -n "$product_name" && "$product_name" != "unknown" ]]; then
            detected_system="$product_name"
            log_debug "Auto-detected system from DMI sysfs: $detected_system"
        fi
    fi
    
    if [[ -n "$detected_system" ]]; then
        echo "$detected_system"
        return 0
    else
        log_warning "Could not auto-detect system type"
        return 1
    fi
}

# Export system detection functions
export -f get_os_name get_os_version auto_detect_system