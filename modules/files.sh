#!/bin/bash

#===============================================================================
# Bash Utility Library - File Operations Module
#===============================================================================
# Description: File and directory manipulation functions
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for logging)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_FILES_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_FILES_LOADED="true"

#===============================================================================
# FILE AND DIRECTORY FUNCTIONS
#===============================================================================

# Create a timestamped backup copy of a file
# Generates backup with format: filename.backup.YYYYMMDD_HHMMSS
# Usage: backup_path=$(create_backup "/etc/hosts" "/tmp/backups")
# Arguments:
#   $1 - source file path to backup
#   $2 - optional backup directory (default: same as source file directory)
#   $3 - optional backup filename base (default: source filename)
# Returns: 0 on success, 1 on failure; prints backup path to stdout
create_backup() {
    local source_file="$1"
    local backup_dir="${2:-$(dirname "$source_file")}"
    local backup_name="${3:-$(basename "$source_file")}"
    
    if [[ ! -f "$source_file" ]]; then
        log_warning "Source file does not exist: $source_file"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    local backup_file="${backup_dir}/${backup_name}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$source_file" "$backup_file"; then
        log_info "Created backup: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_error "Failed to create backup for $source_file"
        return 1
    fi
}

# Create directory if it doesn't exist, with specified permissions
# Creates parent directories as needed (like mkdir -p)
# Usage: ensure_directory "/var/log/myapp" "750"
# Arguments:
#   $1 - directory path to create
#   $2 - optional permissions (default: 755)
# Returns: 0 on success, 1 on failure
ensure_directory() {
    local dir="$1"
    local permissions="${2:-755}"
    
    if [[ ! -d "$dir" ]]; then
        if mkdir -p "$dir"; then
            chmod "$permissions" "$dir"
            log_debug "Created directory: $dir"
            return 0
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    fi
    
    return 0
}

# Get the absolute path of a file or directory
# Resolves relative paths and symbolic links
# Usage: abs_path=$(get_absolute_path "../config.txt")
# Arguments:
#   $1 - file or directory path to resolve
# Returns: 0 on success, 1 if path doesn't exist; prints absolute path to stdout
get_absolute_path() {
    local path="$1"
    
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        local dir=$(dirname "$path")
        local file=$(basename "$path")
        echo "$(cd "$dir" && pwd)/$file"
    else
        log_error "Path does not exist: $path"
        return 1
    fi
}

# Get the directory containing the calling script
# Resolves symbolic links to get the actual script location
# Usage: script_dir=$(get_script_dir)
# Returns: directory path containing the calling script
get_script_dir() {
    local script_path="${BASH_SOURCE[1]}"
    if [[ -L "$script_path" ]]; then
        script_path=$(readlink -f "$script_path")
    fi
    dirname "$script_path"
}

# Get the name of the calling script (filename only, no path)
# Usage: script_name=$(get_script_name)
# Returns: filename of the calling script
get_script_name() {
    basename "${BASH_SOURCE[1]}"
}

# Export all file operation functions for use in other scripts
export -f create_backup ensure_directory get_absolute_path get_script_dir get_script_name