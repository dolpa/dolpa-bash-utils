#!/bin/bash

#===============================================================================
# BATS Test Helper Functions
#===============================================================================
# Common utilities and helper functions used across all test files
#===============================================================================

# Create a temporary file with optional content for testing
# Usage: temp_file=$(create_temp_file "test content")
# Arguments:
#   $1 - optional content for the file (default: "test content")
# Returns: path to created temporary file
create_temp_file() {
    local content="${1:-test content}"
    local temp_file
    temp_file="$(mktemp)"
    echo "$content" > "$temp_file"
    echo "$temp_file"
}

# Create a temporary directory for testing
# Usage: temp_dir=$(create_temp_dir)
# Returns: path to created temporary directory
create_temp_dir() {
    mktemp -d
}

# Helper function to check if a function is exported
is_function_exported() {
    local func_name="$1"
    declare -F "$func_name" >/dev/null 2>&1
}

# Helper function to test log output format
assert_log_format() {
    local output="$1"
    local level="$2"
    local message="$3"
    
    [[ "$output" == *"[$level]"* ]]
    [[ "$output" == *"$message"* ]]
}

# Helper function to count lines in output
count_lines() {
    local output="$1"
    echo "$output" | wc -l
}

# Helper function to remove ANSI color codes from output
strip_colors() {
    local input="$1"
    echo "$input" | sed 's/\x1b\[[0-9;]*m//g'
}

# Helper function to test file permissions
has_permission() {
    local file="$1"
    local permission="$2"
    
    case "$permission" in
        "readable")
            [ -r "$file" ]
            ;;
        "writable")
            [ -w "$file" ]
            ;;
        "executable")
            [ -x "$file" ]
            ;;
        *)
            return 1
            ;;
    esac
}

# Helper function to simulate user input for interactive functions
simulate_input() {
    local input="$1"
    echo "$input"
}

# Helper function to check if string matches pattern
matches_pattern() {
    local string="$1"
    local pattern="$2"
    [[ "$string" =~ $pattern ]]
}

# Helper function to setup test environment
setup_test_env() {
    export NO_COLOR=1
    export BASH_UTILS_VERBOSE=false
    export BASH_UTILS_DEBUG=false
}

# Helper function to cleanup test environment
cleanup_test_env() {
    # Only unset non-readonly variables
    unset NO_COLOR || true
    unset BASH_UTILS_VERBOSE || true
    unset BASH_UTILS_DEBUG || true
    unset TERM || true
    # Note: readonly variables like BASH_UTILS_*_LOADED cannot be unset
}