#!/usr/bin/env bats

# Test system.sh module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/system.sh"
    
    # Disable colors for consistent testing
    export NO_COLOR=1
}

teardown() {
    # Note: Cannot unset readonly variables
    true
}

@test "system module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/system.sh"
    [ "$status" -eq 0 ]
}

@test "system module sets BASH_UTILS_SYSTEM_LOADED" {
    [ "$BASH_UTILS_SYSTEM_LOADED" = "true" ]
}

@test "get_os_name returns a value" {
    result=$(get_os_name)
    [ -n "$result" ]
}

@test "get_os_version returns a value" {
    result=$(get_os_version)
    [ -n "$result" ]
}

@test "auto_detect_system function exists" {
    # This function may fail on systems without DMI info
    # Just test that it exists and doesn't crash
    run auto_detect_system
    # Status can be 0 (success) or 1 (no DMI info), both are valid
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# Note: More comprehensive system tests would require
# specific system configurations and are environment-dependent