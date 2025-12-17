#!/usr/bin/env bats

#=====================================================================
# Test suite for the ansi.sh module
#
# The style follows the other test files in the repository:
#   • All required modules are sourced in the correct order.
#   • Colours are disabled (NO_COLOR=1) for deterministic output.
#   • Environment variables that can be changed by the tests are
#     reset in teardown().
#   • Each public function is exercised with both success and failure
#     cases where possible.
#   • Mock functions are used to test color support detection.
#=====================================================================

# ------------------------------------------------------------------
# Global setup – executed before *any* test case.
# ------------------------------------------------------------------
setup() {
    # Load the library modules in dependency order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/ansi.sh"

    # Store original environment for restoration
    ORIGINAL_NO_COLOR="${NO_COLOR:-}"
    ORIGINAL_TERM="${TERM:-}"
    ORIGINAL_FORCE_COLOR="${BASH_UTILS_FORCE_COLOR:-}"
    
    # Create temporary directory for testing
    TEST_TEMP_DIR=$(mktemp -d)
    
    # Save original functions to restore after tests
    if declare -f _ansi_supports_color >/dev/null; then
        eval "_original_ansi_supports_color() $(declare -f _ansi_supports_color | sed 1d)"
    fi
}

# ------------------------------------------------------------------
# Global teardown – executed after *each* test case.
# ------------------------------------------------------------------
teardown() {
    # Restore original functions
    if declare -f _original_ansi_supports_color >/dev/null; then
        eval "_ansi_supports_color() $(declare -f _original_ansi_supports_color | sed 1d)"
        unset -f _original_ansi_supports_color
    fi
    
    # Clean up test directory
    [[ -d "${TEST_TEMP_DIR:-}" ]] && rm -rf "${TEST_TEMP_DIR}"
    
    # Restore original environment
    export NO_COLOR="${ORIGINAL_NO_COLOR:-}"
    export TERM="${ORIGINAL_TERM:-}"
    export BASH_UTILS_FORCE_COLOR="${ORIGINAL_FORCE_COLOR:-}"
    
    # Clean up test variables
    unset ORIGINAL_NO_COLOR ORIGINAL_TERM ORIGINAL_FORCE_COLOR TEST_TEMP_DIR
}

# ------------------------------------------------------------------
# Mock functions for testing color support detection
# ------------------------------------------------------------------
mock_ansi_supports_color_true() {
    return 0
}

mock_ansi_supports_color_false() {
    return 1
}

mock_ansi_supports_color_with_term_check() {
    [[ "${TERM:-}" != "dumb" ]] && [[ -n "${TERM:-}" ]]
}

# ------------------------------------------------------------------
# Verify the module loads correctly and the loaded flag is set.
# ------------------------------------------------------------------
@test "ansi module reports that it has been loaded" {
    [ -n "${BASH_UTILS_ANSI_LOADED:-}" ]
}

# ------------------------------------------------------------------
# Color support detection tests
# ------------------------------------------------------------------
@test "ansi_supports_color returns correct status" {
    # Test with colors disabled
    export NO_COLOR=1
    run ansi_supports_color
    [ "$status" -eq 1 ]
    
    # Test with colors enabled and good terminal
    unset NO_COLOR
    export TERM=xterm-256color
    export BASH_UTILS_FORCE_COLOR=true
    run ansi_supports_color
    [ "$status" -eq 0 ]
    
    # Test with dumb terminal
    export TERM=dumb
    export BASH_UTILS_FORCE_COLOR=false
    run ansi_supports_color
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# Basic color functions tests - with colors disabled
# ------------------------------------------------------------------
@test "ansi_red works with colors disabled" {
    export NO_COLOR=1
    run ansi_red "error message"
    [ "$status" -eq 0 ]
    [ "$output" = "error message" ]
}

@test "ansi_green works with colors disabled" {
    export NO_COLOR=1
    run ansi_green "success message"
    [ "$status" -eq 0 ]
    [ "$output" = "success message" ]
}

@test "ansi_yellow works with colors disabled" {
    export NO_COLOR=1
    run ansi_yellow "warning message"
    [ "$status" -eq 0 ]
    [ "$output" = "warning message" ]
}

@test "ansi_blue works with colors disabled" {
    export NO_COLOR=1
    run ansi_blue "info message"
    [ "$status" -eq 0 ]
    [ "$output" = "info message" ]
}

@test "ansi_purple works with colors disabled" {
    export NO_COLOR=1
    run ansi_purple "debug message"
    [ "$status" -eq 0 ]
    [ "$output" = "debug message" ]
}

@test "ansi_cyan works with colors disabled" {
    export NO_COLOR=1
    run ansi_cyan "processing message"
    [ "$status" -eq 0 ]
    [ "$output" = "processing message" ]
}

# ------------------------------------------------------------------
# Basic color functions tests - with colors enabled
# ------------------------------------------------------------------
@test "ansi_red produces ANSI codes when colors enabled" {
    # Set environment for color support
    export BASH_UTILS_FORCE_COLOR=true
    unset NO_COLOR
    export TERM=xterm-256color
    
    run ansi_red "error"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" =~ $'\033' ]]
    # Should contain the text
    [[ "$output" =~ error ]]
}

@test "ansi_green produces ANSI codes when colors enabled" {
    # Set environment for color support
    export BASH_UTILS_FORCE_COLOR=true
    unset NO_COLOR
    export TERM=xterm-256color
    
    run ansi_green "success"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" =~ $'\033' ]]
    # Should contain the text
    [[ "$output" =~ success ]]
}

# ------------------------------------------------------------------
# Bright color functions tests
# ------------------------------------------------------------------
@test "ansi_bright_red works with colors disabled" {
    export NO_COLOR=1
    run ansi_bright_red "critical error"
    [ "$status" -eq 0 ]
    [ "$output" = "critical error" ]
}

@test "ansi_bright_green produces ANSI codes when colors enabled" {
    # Set environment for color support
    unset NO_COLOR
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=xterm-256color
    
    run ansi_bright_green "great success"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" =~ $'\033' ]]
    # Should contain the text
    [[ "$output" =~ "great success" ]]
}

# ------------------------------------------------------------------
# Text style functions tests
# ------------------------------------------------------------------
@test "ansi_bold works with colors disabled" {
    export NO_COLOR=1
    run ansi_bold "important text"
    [ "$status" -eq 0 ]
    [ "$output" = "important text" ]
}

@test "ansi_underline works with colors disabled" {
    export NO_COLOR=1
    run ansi_underline "section header"
    [ "$status" -eq 0 ]
    [ "$output" = "section header" ]
}

@test "ansi_dim works with colors disabled" {
    export NO_COLOR=1
    run ansi_dim "less important"
    [ "$status" -eq 0 ]
    [ "$output" = "less important" ]
}

@test "ansi_bold produces ANSI codes when colors enabled" {
    # Set environment for color support
    unset NO_COLOR
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=xterm-256color
    
    run ansi_bold "bold text"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" =~ $'\033' ]]
    # Should contain the text
    [[ "$output" =~ "bold text" ]]
}

# ------------------------------------------------------------------
# Background color functions tests
# ------------------------------------------------------------------
@test "ansi_bg_red works with colors disabled" {
    export NO_COLOR=1
    run ansi_bg_red "ERROR"
    [ "$status" -eq 0 ]
    [ "$output" = "ERROR" ]
}

@test "ansi_bg_green works with colors disabled" {
    export NO_COLOR=1
    run ansi_bg_green "SUCCESS"
    [ "$status" -eq 0 ]
    [ "$output" = "SUCCESS" ]
}

@test "ansi_bg_yellow produces ANSI codes when colors enabled" {
    # Set environment for color support
    unset NO_COLOR
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=xterm-256color
    
    run ansi_bg_yellow "WARNING"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" =~ $'\033' ]]
    # Should contain the text
    [[ "$output" =~ WARNING ]]
}

# ------------------------------------------------------------------
# Composite formatting functions tests
# ------------------------------------------------------------------
@test "ansi_error provides fallback text when colors disabled" {
    export NO_COLOR=1
    run ansi_error "File not found"
    [ "$status" -eq 0 ]
    [ "$output" = "ERROR: File not found" ]
}

@test "ansi_success provides fallback text when colors disabled" {
    export NO_COLOR=1
    run ansi_success "Operation completed"
    [ "$status" -eq 0 ]
    [ "$output" = "SUCCESS: Operation completed" ]
}

@test "ansi_warning provides fallback text when colors disabled" {
    export NO_COLOR=1
    run ansi_warning "Config outdated"
    [ "$status" -eq 0 ]
    [ "$output" = "WARNING: Config outdated" ]
}

@test "ansi_info provides fallback text when colors disabled" {
    export NO_COLOR=1
    run ansi_info "Processing files"
    [ "$status" -eq 0 ]
    [ "$output" = "INFO: Processing files" ]
}

@test "ansi_header provides fallback text when colors disabled" {
    export NO_COLOR=1
    run ansi_header "Configuration"
    [ "$status" -eq 0 ]
    [ "$output" = "=== Configuration ===" ]
}

@test "ansi_code provides fallback text when colors disabled" {
    export NO_COLOR=1
    run ansi_code "make install"
    [ "$status" -eq 0 ]
    [ "$output" = "\`make install\`" ]
}

@test "ansi_error produces ANSI codes when colors enabled" {
    # Set environment for color support
    unset NO_COLOR
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=xterm-256color
    
    run ansi_error "Critical failure"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" =~ $'\033' ]]
    # Should contain the text
    [[ "$output" =~ "Critical failure" ]]
    # Should not contain fallback prefix
    [[ ! "$output" =~ "ERROR:" ]]
}

# ------------------------------------------------------------------
# Utility functions tests
# ------------------------------------------------------------------
@test "ansi_reset returns empty string when colors disabled" {
    export NO_COLOR=1
    run ansi_reset
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "ansi_reset returns ANSI code when colors enabled" {
    # Set environment for color support
    unset NO_COLOR
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=xterm-256color
    
    run ansi_reset
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequence
    [[ "$output" =~ $'\033' ]]
}

@test "ansi_strip removes ANSI sequences" {
    local test_text="$(printf '\033[31mRed text\033[0m normal text')"
    run ansi_strip "$test_text"
    [ "$status" -eq 0 ]
    [ "$output" = "Red text normal text" ]
}

@test "ansi_strip handles text without ANSI sequences" {
    run ansi_strip "plain text"
    [ "$status" -eq 0 ]
    [ "$output" = "plain text" ]
}

@test "ansi_strip handles empty input" {
    run ansi_strip ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "ansi_length returns correct visible length" {
    local test_text="$(printf '\033[31mRed\033[0m text')"
    run ansi_length "$test_text"
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]  # "Red text" = 8 characters
}

@test "ansi_length handles plain text correctly" {
    run ansi_length "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "11" ]
}

@test "ansi_length handles empty input" {
    run ansi_length ""
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

# ------------------------------------------------------------------
# Color test function
# ------------------------------------------------------------------
@test "ansi_test_colors runs without errors" {
    run ansi_test_colors
    [ "$status" -eq 0 ]
    # Should contain expected sections
    [[ "$output" =~ "ANSI Color and Formatting Test" ]]
    [[ "$output" =~ "Basic Colors:" ]]
    [[ "$output" =~ "Bright Colors:" ]]
    [[ "$output" =~ "Text Styles:" ]]
    [[ "$output" =~ "Background Colors:" ]]
    [[ "$output" =~ "Composite Styles:" ]]
    [[ "$output" =~ "Color Support:" ]]
}

# ------------------------------------------------------------------
# Environment variable handling tests
# ------------------------------------------------------------------
@test "NO_COLOR=1 disables all color functions" {
    export NO_COLOR=1
    
    # Test multiple functions to ensure they all respect NO_COLOR
    red_output=$(ansi_red "test")
    green_output=$(ansi_green "test")
    bold_output=$(ansi_bold "test")
    
    [ "$red_output" = "test" ]
    [ "$green_output" = "test" ]
    [ "$bold_output" = "test" ]
}

@test "BASH_UTILS_FORCE_COLOR=true enables colors" {
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=dumb  # Would normally disable colors
    unset NO_COLOR
    
    run ansi_supports_color
    [ "$status" -eq 0 ]
}

@test "TERM=dumb disables colors when not forced" {
    export TERM=dumb
    export BASH_UTILS_FORCE_COLOR=false
    unset NO_COLOR
    
    run ansi_supports_color
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# Edge cases and error handling
# ------------------------------------------------------------------
@test "ansi functions handle empty input gracefully" {
    export NO_COLOR=1
    
    run ansi_red ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    
    run ansi_bold ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    
    run ansi_error ""
    [ "$status" -eq 0 ]
    [ "$output" = "ERROR: " ]
}

@test "ansi functions handle special characters in input" {
    export NO_COLOR=1
    
    run ansi_red "test with \$VAR and 'quotes'"
    [ "$status" -eq 0 ]
    [ "$output" = "test with \$VAR and 'quotes'" ]
    
    run ansi_success "path/to/file.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "SUCCESS: path/to/file.txt" ]
}

@test "ansi functions handle multiline input" {
    export NO_COLOR=1
    local multiline_text="line 1
line 2
line 3"
    
    run ansi_blue "$multiline_text"
    [ "$status" -eq 0 ]
    [ "$output" = "$multiline_text" ]
}

# ------------------------------------------------------------------
# Integration tests with actual ANSI sequences
# ------------------------------------------------------------------
@test "complex formatting combinations work correctly" {
    # Set environment for color support
    unset NO_COLOR
    export BASH_UTILS_FORCE_COLOR=true
    export TERM=xterm-256color
    
    # Test that complex combinations don't break (avoid brittle nested quoting).
    local output
    output="$(ansi_bold "$(ansi_red "Bold Red")")"

    # Should contain at least two ESC bytes (nested formatting + reset).
    [[ "$output" =~ $'\033'.*$'\033' ]]
    # Should still contain the text
    [[ "$output" =~ "Bold Red" ]]
}

#=====================================================================
# END OF TEST FILE
#=====================================================================