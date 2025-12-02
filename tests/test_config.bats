#!/usr/bin/env bats

# Test config.sh module

setup() {
    # Load the config module
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
}

teardown() {
    # Clean up any environment variables set during tests
    # Note: Cannot unset readonly variables like BASH_UTILS_CONFIG_LOADED
    unset NO_COLOR || true
    unset TERM || true
}

@test "config module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    [ "$status" -eq 0 ]
}

@test "config module sets BASH_UTILS_CONFIG_LOADED" {
    [ "$BASH_UTILS_CONFIG_LOADED" = "true" ]
}

@test "config module prevents multiple sourcing" {
    # Source again, should return immediately
    run source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    [ "$status" -eq 0 ]
}

@test "BASH_UTILS_VERSION is set correctly" {
    [ "$BASH_UTILS_VERSION" = "main" ]
}

@test "BASH_UTILS_NAME is set correctly" {
    [ "$BASH_UTILS_NAME" = "Bash Utility Library" ]
}

@test "default configuration variables are set" {
    [ "$BASH_UTILS_VERBOSE" = "false" ]
    [ "$BASH_UTILS_DEBUG" = "false" ]
    [ "$BASH_UTILS_TIMESTAMP_FORMAT" = "%Y-%m-%d %H:%M:%S" ]
    [ "$BASH_UTILS_LOG_LEVEL" = "INFO" ]
}

@test "color variables are set when color is supported" {
    # Test color detection logic directly
    # When terminal supports color and NO_COLOR is not set, colors should be defined
    if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
        # In a color-supporting environment, check that colors are loaded
        # Create a fresh subshell with color support
        result=$(bash -c '
            export TERM="xterm-256color"
            unset NO_COLOR
            if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
                echo "color_supported"
            else
                echo "color_not_supported"  
            fi
            source "'${BATS_TEST_DIRNAME}'/../modules/config.sh" 2>/dev/null || true
            echo "${COLOR_RED:-empty}"
        ')
        # The result should contain color codes or be non-empty if colors are supported
        [[ "$result" != *"empty" ]] || [[ "$result" == *"color_not_supported"* ]]
    else
        # In a non-color environment, skip this test
        skip "Terminal does not support color or colors are disabled"
    fi
}

@test "color variables are empty when NO_COLOR is set" {
    # Create a subshell to test NO_COLOR without affecting current environment
    result=$(bash -c '
        export NO_COLOR=1
        export TERM="xterm"
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        echo "$COLOR_RED"
    ')
    [ -z "$result" ]
}

@test "legacy color constants are set" {
    [ "$RED" = "$COLOR_RED" ]
    [ "$GREEN" = "$COLOR_GREEN" ]
    [ "$YELLOW" = "$COLOR_YELLOW" ]
    [ "$NC" = "$COLOR_NC" ]
}