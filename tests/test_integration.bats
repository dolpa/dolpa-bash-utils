#!/usr/bin/env bats

# Integration tests for bash-utils.sh main loader

setup() {
    # Disable colors for consistent testing
    export NO_COLOR=1
}

teardown() {
    # Note: Cannot unset readonly module variables once they are set
    # Clean up non-readonly variables only
    unset NO_COLOR || true
    unset TERM || true
}

@test "bash-utils.sh loads all modules successfully" {
    run source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    [ "$status" -eq 0 ]
}

@test "bash-utils.sh sets BASH_UTILS_LOADED" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    [ "$BASH_UTILS_LOADED" = "true" ]
}

@test "bash-utils.sh prevents multiple sourcing" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    # Source again, should return immediately
    run source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    [ "$status" -eq 0 ]
}

@test "all module loaded flags are set" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    [ "$BASH_UTILS_CONFIG_LOADED" = "true" ]
    [ "$BASH_UTILS_LOGGING_LOADED" = "true" ]
    [ "$BASH_UTILS_VALIDATION_LOADED" = "true" ]
    [ "$BASH_UTILS_FILES_LOADED" = "true" ]
    [ "$BASH_UTILS_FILESYSTEM_LOADED" = "true" ]
    [ "$BASH_UTILS_SYSTEM_LOADED" = "true" ]
    [ "$BASH_UTILS_UTILITIES_LOADED" = "true" ]
    [ "$BASH_UTILS_STRINGS_LOADED" = "true" ]
    [ "$BASH_UTILS_PROMPTS_LOADED" = "true" ]
    [ "$BASH_UTILS_EXEC_LOADED" = "true" ]
    [ "$BASH_UTILS_NETWORK_LOADED" = "true" ]
    [ "$BASH_UTILS_APPLICATIONS_LOADED" = "true" ]
    [ "$BASH_UTILS_ENV_LOADED" = "true" ]
}

@test "bash_utils_info function is available" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    run bash_utils_info
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bash Utility Library"* ]]
    [[ "$output" == *"Loaded Modules:"* ]]
}

@test "functions from all modules are available" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    
    # Test a function from each module
    
    # From logging.sh
    run log_info "test"
    [ "$status" -eq 0 ]
    
    # From validation.sh
    run command_exists "echo"
    [ "$status" -eq 0 ]
    
    # From files.sh
    run get_script_name
    [ "$status" -eq 0 ]
    
    # From system.sh
    run get_os_name
    [ "$status" -eq 0 ]
    
    # From utils.sh
    run seconds_to_human 60
    [ "$status" -eq 0 ]
}

@test "color constants are available" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    # Colors should be empty due to NO_COLOR=1
    [ -z "$COLOR_RED" ]
    [ -z "$COLOR_GREEN" ]
    [ -z "$COLOR_NC" ]
}

@test "configuration variables are set" {
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    [ "$BASH_UTILS_VERSION" = "main" ]
    [ "$BASH_UTILS_NAME" = "Bash Utility Library" ]
}

@test "cross-module functionality works" {
    # Ensure the main loader has been sourced
    source "${BATS_TEST_DIRNAME}/../bash-utils.sh"
    
    # Test that logging functions work (they use colors from config)
    run log_info "test with colors"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test with colors"* ]]
}