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

# Detect and return the operating system name
# Uses multiple detection methods for maximum compatibility
# Usage: os_name=$(get_os_name)
# Returns: operating system name string
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

# Detect and return the operating system version
# Uses multiple detection methods for maximum compatibility
# Usage: os_version=$(get_os_version)
# Returns: operating system version string
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

# -----------------------------
# Sysctl profile detection
# -----------------------------

_sysctl_slugify() {
    # Lowercase, whitespace to '-', strip unsupported characters
    echo "$*" | tr '[:upper:]' '[:lower:]' | tr '[:space:]' '-' | sed 's/[^a-z0-9_-]//g'
}

_dmi_read() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    cat "$path" 2>/dev/null
}

get_system_fingerprint() {
    # Best-effort, non-root fingerprint from sysfs DMI.
    local vendor product board
    vendor=$(_dmi_read /sys/class/dmi/id/sys_vendor || true)
    product=$(_dmi_read /sys/class/dmi/id/product_name || true)
    board=$(_dmi_read /sys/class/dmi/id/board_name || true)
    vendor=$(_sysctl_slugify "$vendor")
    product=$(_sysctl_slugify "$product")
    board=$(_sysctl_slugify "$board")
    echo "${vendor} ${product} ${board}" | tr ' ' '-'
}

list_sysctl_profiles() {
    local config_dir="$1"
    [[ -d "$config_dir" ]] || return 1

    local systems=()
    local file

    # Performance files may have a historical typo: 'performanc'.
    for file in "$config_dir"/99-*-performance.conf "$config_dir"/99-*-performanc.conf; do
        [[ -f "$file" ]] || continue

        local base
        base=$(basename "$file")
        local system_name
        system_name=$(echo "$base" | sed -E 's/^99-(.*)-(performance|performanc)\.conf$/\1/')

        local security_file="$config_dir/99-${system_name}-security.conf"
        [[ -f "$security_file" ]] || continue
        systems+=("$system_name")
    done

    # Deduplicate
    if (( ${#systems[@]} > 0 )); then
        printf '%s\n' "${systems[@]}" | awk '!seen[$0]++'
    fi
}

auto_detect_sysctl_profile() {
    # Usage: auto_detect_sysctl_profile <config_dir>
    # Honors SYSCTL_SYSTEM_NAME (or DOLPA_SYSCTL_SYSTEM_NAME) override.
    local config_dir="${1:-}"

    if [[ -n "${SYSCTL_SYSTEM_NAME:-}" ]]; then
        echo "${SYSCTL_SYSTEM_NAME}"
        return 0
    fi
    if [[ -n "${DOLPA_SYSCTL_SYSTEM_NAME:-}" ]]; then
        echo "${DOLPA_SYSCTL_SYSTEM_NAME}"
        return 0
    fi

    local fingerprint
    fingerprint=$(get_system_fingerprint | _sysctl_slugify)
    log_debug "System fingerprint: $fingerprint"

    local candidates=()
    if [[ -n "$config_dir" && -d "$config_dir" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && candidates+=("$line")
        done < <(list_sysctl_profiles "$config_dir" || true)
    fi

    # If we can’t see candidates, fall back to the generic DMI detection.
    if (( ${#candidates[@]} == 0 )); then
        auto_detect_system
        return $?
    fi

    # 1) Substring match (pick the longest matching candidate).
    local best=""
    local best_len=0
    local c
    for c in "${candidates[@]}"; do
        if [[ "$fingerprint" == *"$c"* ]]; then
            if (( ${#c} > best_len )); then
                best="$c"
                best_len=${#c}
            fi
        fi
    done
    if [[ -n "$best" ]]; then
        log_debug "Matched sysctl profile by substring: $best"
        echo "$best"
        return 0
    fi

    # 2) Heuristic mappings for common machines / your AI server.
    local fp="$fingerprint"
    if [[ "$fp" == *"dell"* && "$fp" == *"xps"* ]]; then
        if printf '%s\n' "${candidates[@]}" | grep -qx "dell-xps"; then
            echo "dell-xps"
            return 0
        fi
    fi
    if [[ "$fp" == *"thinkpad"* && "$fp" == *"x1"* ]] || [[ "$fp" == *"lenovo"* && "$fp" == *"x1"* ]]; then
        if printf '%s\n' "${candidates[@]}" | grep -qx "thinkpad-x1"; then
            echo "thinkpad-x1"
            return 0
        fi
    fi
    if [[ "$fp" == *"x88"* ]]; then
        if printf '%s\n' "${candidates[@]}" | grep -qx "ai-x88-srv"; then
            echo "ai-x88-srv"
            return 0
        fi
    fi

    log_warning "Could not map this machine to an available sysctl profile"
    log_info "Available profiles: $(printf '%s ' "${candidates[@]}")"
    return 1
}

# Export system detection functions
export -f get_os_name get_os_version auto_detect_system get_system_fingerprint list_sysctl_profiles auto_detect_sysctl_profile